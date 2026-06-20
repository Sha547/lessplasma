#!/usr/bin/env python3
"""
Screen Time daemon for KDE Plasma.
DBus service org.kde.ScreenTime. Tracks active app per hour, categorizes,
and exposes JSON queries for the plasmoid.
"""

import json
import os
import signal
import sqlite3
import time
from datetime import date, datetime
from pathlib import Path

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

BUS_NAME = "org.kde.ScreenTime"
OBJECT_PATH = "/ScreenTime"
IFACE = "org.kde.ScreenTime"

DATA_DIR = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "plasma-screentime"
DB_PATH = DATA_DIR / "usage.db"
CATEGORIES_PATH = DATA_DIR / "categories.json"

IDLE_THRESHOLD_SEC = 180
TICK_SEC = 10

DEFAULT_CATEGORIES = {
    "Entertainment": [
        "vlc", "mpv", "netflix", "youtube", "spotify", "plex", "jellyfin",
        "kodi", "stremio", "smplayer", "elisa", "audacious", "youtube_music",
        "retroarch", "duckstation"
    ],
    "Gaming": [
        "steam", "steam_app", "lutris", "bottles", "prismlauncher", 
        "hydralauncher", "heroic"
    ],
    "Social": [
        "discord", "telegram", "telegram-desktop", "slack", "signal", "whatsapp",
        "element", "thunderbird", "evolution", "kmail", "geary", "skype", "zoom",
        "vesktop"
    ],
    "Creativity": [
        "gimp", "krita", "blender", "inkscape", "code", "code-oss", "vscode",
        "konsole", "kate", "kwrite", "qtcreator", "intellij-idea", "android-studio",
        "obs", "kdenlive", "darktable", "rawtherapee", "audacity", "antigravity",
        "kitty", "alacritty", "termius"
    ],
    "Productivity": [
        "libreoffice", "calligra", "okular", "evince", "logseq", "obsidian",
        "notion", "typora", "joplin", "thunderbird-calendar", "korganizer",
        "fdm", "jdownloader", "calibre", "proton pass", "localsend",
        "rclone"
    ],
    "Browsing": [
        "firefox", "chromium", "google-chrome", "brave", "opera", "vivaldi",
        "tor browser", "torbrowser", "zen-bin", "librewolf", "falkon"
    ],
    "System": [
        "systemsettings", "kcmshell6", "plasma-systemmonitor", "spectacle",
        "gparted", "stacer", "missioncenter", "btrfs-assistant", "krunner",
        "dolphin", "ark", "filelight", "waydroid"
    ]
}

CATEGORY_COLORS = {
    "Entertainment": "#FF9F0A",
    "Gaming": "#5856D6",
    "Social": "#34C759",
    "Creativity": "#5AC8FA",
    "Productivity": "#AF52DE",
    "Browsing": "#FF3B30",
    "System": "#007AFF",
    "Other": "#8E8E93",
}


def today_key():
    return date.today().isoformat()


class CategoryMap:
    def __init__(self, path: Path):
        self.path = path
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.exists():
            path.write_text(json.dumps(DEFAULT_CATEGORIES, indent=2))
        try:
            self.mapping = json.loads(path.read_text())
        except Exception:
            self.mapping = dict(DEFAULT_CATEGORIES)
        # Build reverse: app_lc -> category
        self._reverse = {}
        for cat, apps in self.mapping.items():
            for app in apps:
                self._reverse[app.lower()] = cat

    def category_of(self, app: str) -> str:
        lc = (app or "").lower()
        if lc in self._reverse:
            return self._reverse[lc]
        # Loose match: app contains a known token
        for token, cat in self._reverse.items():
            if token and token in lc:
                return cat
        return "Other"


class UsageStore:
    def __init__(self, path: Path):
        path.parent.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(str(path))
        self.conn.execute(
            """CREATE TABLE IF NOT EXISTS usage (
                day TEXT NOT NULL,
                hour INTEGER NOT NULL,
                app TEXT NOT NULL,
                seconds INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (day, hour, app)
            )"""
        )
        # Migrate from old schema if needed
        cols = [r[1] for r in self.conn.execute("PRAGMA table_info(usage)").fetchall()]
        if "hour" not in cols:
            self.conn.execute("ALTER TABLE usage RENAME TO usage_old")
            self.conn.execute(
                """CREATE TABLE usage (
                    day TEXT NOT NULL,
                    hour INTEGER NOT NULL,
                    app TEXT NOT NULL,
                    seconds INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (day, hour, app)
                )"""
            )
            self.conn.execute(
                "INSERT INTO usage(day, hour, app, seconds) "
                "SELECT day, 0, app, seconds FROM usage_old"
            )
            self.conn.execute("DROP TABLE usage_old")
        self.conn.commit()

    def add(self, app: str, seconds: int):
        if seconds <= 0 or not app:
            return
        hour = datetime.now().hour
        self.conn.execute(
            "INSERT INTO usage(day, hour, app, seconds) VALUES(?, ?, ?, ?) "
            "ON CONFLICT(day, hour, app) DO UPDATE SET seconds = seconds + excluded.seconds",
            (today_key(), hour, app, seconds),
        )
        self.conn.commit()

    def today_total(self) -> int:
        cur = self.conn.execute(
            "SELECT COALESCE(SUM(seconds), 0) FROM usage WHERE day = ?", (today_key(),)
        )
        return int(cur.fetchone()[0])

    def today_top_apps(self, n: int = 6):
        cur = self.conn.execute(
            "SELECT app, SUM(seconds) AS s FROM usage WHERE day = ? "
            "GROUP BY app ORDER BY s DESC LIMIT ?",
            (today_key(), n),
        )
        return [{"app": a, "seconds": int(s)} for a, s in cur.fetchall()]

    def today_hourly_by_category(self, cmap: CategoryMap):
        """Return {hour: {category: seconds}} for today."""
        cur = self.conn.execute(
            "SELECT hour, app, SUM(seconds) FROM usage WHERE day = ? GROUP BY hour, app",
            (today_key(),),
        )
        out = {h: {} for h in range(24)}
        for hour, app, secs in cur.fetchall():
            cat = cmap.category_of(app)
            out[hour][cat] = out[hour].get(cat, 0) + int(secs)
        return out

    def today_category_totals(self, cmap: CategoryMap):
        cur = self.conn.execute(
            "SELECT app, SUM(seconds) FROM usage WHERE day = ? GROUP BY app",
            (today_key(),),
        )
        totals = {}
        for app, secs in cur.fetchall():
            cat = cmap.category_of(app)
            totals[cat] = totals.get(cat, 0) + int(secs)
        return totals


def idle_ms() -> int:
    try:
        bus = dbus.SessionBus()
        proxy = bus.get_object("org.freedesktop.ScreenSaver", "/ScreenSaver")
        iface = dbus.Interface(proxy, "org.freedesktop.ScreenSaver")
        return int(iface.GetSessionIdleTime())
    except Exception:
        return 0


class ScreenTimeService(dbus.service.Object):
    def __init__(self, bus, store: UsageStore, cmap: CategoryMap):
        super().__init__(bus, OBJECT_PATH)
        self.store = store
        self.cmap = cmap
        self.current_app = None
        self.segment_start = time.time()
        GLib.timeout_add_seconds(TICK_SEC, self._tick)

    def _flush_current(self):
        if not self.current_app:
            self.segment_start = time.time()
            return
        elapsed = int(time.time() - self.segment_start)
        if idle_ms() >= IDLE_THRESHOLD_SEC * 1000:
            elapsed = 0
        if elapsed > 0:
            self.store.add(self.current_app, elapsed)
        self.segment_start = time.time()

    def _tick(self):
        self._flush_current()
        return True

    @dbus.service.method(IFACE, in_signature="ss", out_signature="")
    def RecordEvent(self, app_class, caption):
        self._flush_current()
        app_name = str(app_class) or "unknown"
        if app_name.lower() == "kwin_wayland":
            self.current_app = None
        else:
            self.current_app = app_name

    @dbus.service.method(IFACE, in_signature="", out_signature="s")
    def GetTodayJson(self):
        self._flush_current()
        hourly = self.store.today_hourly_by_category(self.cmap)
        cats = self.store.today_category_totals(self.cmap)
        payload = {
            "total": self.store.today_total(),
            "current": self.current_app,
            "hourly": [
                {
                    "hour": h,
                    "categories": hourly[h],
                }
                for h in range(24)
            ],
            "categories": [
                {"name": cat, "seconds": secs, "color": CATEGORY_COLORS.get(cat, "#8E8E93")}
                for cat, secs in sorted(cats.items(), key=lambda x: -x[1])
            ],
            "top_apps": [
                {**a, "category": self.cmap.category_of(a["app"])}
                for a in self.store.today_top_apps(6)
            ],
        }
        return json.dumps(payload)

    @dbus.service.method(IFACE, in_signature="", out_signature="")
    def Flush(self):
        self._flush_current()


def main():
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    name = dbus.service.BusName(BUS_NAME, bus)
    cmap = CategoryMap(CATEGORIES_PATH)
    store = UsageStore(DB_PATH)
    service = ScreenTimeService(bus, store, cmap)

    loop = GLib.MainLoop()

    def shutdown(*_):
        service.Flush()
        loop.quit()

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    print(f"[screentime] listening on {BUS_NAME}, db={DB_PATH}")
    loop.run()


if __name__ == "__main__":
    main()
