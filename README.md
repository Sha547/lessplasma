<img src="screenshots/hero.svg" alt="lessplasma" width="100%">

<p align="center">
    <a href="https://github.com/Sha547/lessplasma/releases/latest"><img src="https://img.shields.io/github/v/release/Sha547/lessplasma?style=for-the-badge" alt="Latest release"></a>
    <img src="https://img.shields.io/badge/KDE_Plasma-6.0+-blue?style=for-the-badge&logo=kde" alt="KDE Plasma 6">
    <img src="https://img.shields.io/badge/license-GPL--3.0-green?style=for-the-badge" alt="License">
</p>

Eight widgets I built for my own desktop. Dark, dot-friendly, no theme to install. If you like one, take it; the rest are independent.

---

```
$ cat lessplasma.manifest

# eight widgets, all dark, all responsive

screen-time      →  per-app usage by the hour
sticky-note      →  editable note, autosaves
system-pulse     →  CPU / RAM / Net live bars
disk-usage       →  used/free per drive
calendar-strip   →  7-day strip or full month grid
wifi-qr          →  scannable QR for current network
public-ip        →  external IP, country, VPN status
bar-clock        →  time as three filling bars

# each widget is its own folder under packages/
# install:  ./install.sh
# reload:   kquitapp6 plasmashell && kstart plasmashell
```

---

## Screen Time `packages/screen-time`

<img src="screenshots/screen-time.png" alt="Screen Time" width="100%">

This is the only widget here that's more than a single QML file. There's a Python daemon running as a systemd user service, plus a small KWin script that fires on every window-focus change and tells the daemon what window you switched to. The daemon keeps a running tally of seconds per app per hour in SQLite, ignores time when you're idle (it asks `org.freedesktop.ScreenSaver` how long it's been), and the widget polls it every 15 seconds.

If a category in the chart says "Other" and you don't recognize what's in it, edit `~/.local/share/plasma-screentime/categories.json` and the widget will pick the change up automatically.

## Sticky Note `packages/sticky-note`

<img src="screenshots/sticky-note.png" alt="Sticky Note" width="100%">

A `TextArea` that saves to plasmoid config 600ms after you stop typing. That's the whole widget.

## System Pulse `packages/system-pulse`

<img src="screenshots/system-pulse.png" alt="System Pulse" width="100%">

Reads `/proc/stat`, `/proc/meminfo`, `/proc/net/dev` every two seconds. CPU and network are deltas between two reads, RAM is `MemTotal - MemAvailable`. Bars go green, then orange, then red as load climbs.

## Disk Usage `packages/disk-usage`

<img src="screenshots/disk-usage.png" alt="Disk Usage" width="100%">

One row per mounted drive, colored by fullness. The hard part was getting `df` to ignore the dozens of fake filesystems Linux mounts (tmpfs, snap, fuse, overlays) and only show real disks.

## Calendar Strip `packages/calendar-strip`

<img src="screenshots/calendar-strip.png" alt="Calendar Strip" width="100%">

Seven days with a dot for each upcoming event. Drag the corner to make it taller and it switches to a full month grid, with today highlighted as a blue circle. Events come from `DTSTART` lines in your local `.ics` files (Akonadi resources, KOrganizer, anything in `~/.local/share/calendars`). Online-only calendars won't show up; that's a different data source.

## WiFi QR `packages/wifi-qr`

<img src="screenshots/wifi-qr.png" alt="WiFi QR" width="100%">

SSID is auto-detected. Click the ✎ to type your password once; it lives in plasmoid config locally. `qrencode` renders the standard `WIFI:T:WPA;S:<ssid>;P:<pass>;;` payload to a PNG and any phone camera reads it.

## Public IP `packages/public-ip`

<img src="screenshots/public-ip.png" alt="Public IP" width="100%">

Pulls IP, city, country from `ipinfo.io` once a minute. The VPN dot is just `ip link show` greppped for `tun*`, `wg*`, `tap*`, `nordlynx`. It's not foolproof — a VPN running through a `eth*` interface won't trigger it — but covers most setups.

## Bar Clock `packages/bar-clock`

<img src="screenshots/bar-clock.png" alt="Bar Clock" width="100%">

Hours, minutes, seconds as three filling bars. The seconds bar is the only one you'll catch moving.

---

## Install

You'll need:

| Distro | Command |
|---|---|
| Debian / Ubuntu / Neon | `sudo apt install qt6-tools python3-dbus python3-gi curl` |
| Arch | `sudo pacman -S qt6-tools python-dbus python-gobject curl` |
| Fedora | `sudo dnf install qt6-qttools python3-dbus python3-gobject curl` |

Plus `qrencode` if you want WiFi QR.

```bash
git clone https://github.com/Sha547/lessplasma.git
cd lessplasma
./install.sh
kquitapp6 plasmashell && kstart plasmashell
```

The installer checks deps upfront, registers each plasmoid via `kpackagetool6`, and sets up the Screen Time daemon. Once that's done, right-click desktop → **Add Widgets** → search the widget name.

## Configure

- **Screen Time** — categories live at `~/.local/share/plasma-screentime/categories.json`. Edit to add your apps (substring match).
- **WiFi QR** — click ✎ in the widget to set your password.
- **Sticky Note** — just type.

## Uninstall

```bash
./uninstall.sh
```

Plasmoids and daemon go. Your usage data at `~/.local/share/plasma-screentime/` stays unless you delete it.

## Credits

Massive thanks to my friend **Jack Faith ([@jaxparrow07](https://github.com/jaxparrow07))** — his [**nothingkdewidgets**](https://github.com/jaxparrow07/nothing-kde-widgets) pack is what got me into building these in the first place. The install-script structure and packaging conventions in this repo are based on his. His widgets are also genuinely beautiful, go install them.

## License

[GPL-3.0-or-later](LICENSE).
