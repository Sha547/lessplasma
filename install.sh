#!/usr/bin/env bash
# lessplasma installer
# Installs widget plasmoids + Screen Time daemon (systemd user unit).
#
# Usage:
#   ./install.sh                  Install all widgets
#   ./install.sh --all  | -a      Install all widgets
#   ./install.sh <widget-name>    Install a single widget (e.g. ./install.sh sticky-note)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES="$ROOT/packages"

# ──────────────────────────────────────────────────────────────────────
# Dependency check
# ──────────────────────────────────────────────────────────────────────

# Locate qdbus6. On Fedora it's at /usr/lib64/qt6/bin/ and not on PATH by default.
QDBUS6_BIN=""
for candidate in qdbus6 /usr/lib64/qt6/bin/qdbus6 /usr/lib/qt6/bin/qdbus6 /usr/libexec/qt6/qdbus6 qdbus-qt6; do
    if command -v "$candidate" >/dev/null 2>&1; then
        QDBUS6_BIN=$(command -v "$candidate")
        break
    fi
    if [ -x "$candidate" ]; then
        QDBUS6_BIN="$candidate"
        break
    fi
done

# If qdbus6 was found but isn't on PATH, symlink it so the widget runtime
# can call it without users editing their shell rc.
if [ -n "$QDBUS6_BIN" ] && ! command -v qdbus6 >/dev/null 2>&1; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$QDBUS6_BIN" "$HOME/.local/bin/qdbus6"
    echo "Note: linked $QDBUS6_BIN → ~/.local/bin/qdbus6 (Fedora's Qt6 bin dir isn't on PATH)."
    export PATH="$HOME/.local/bin:$PATH"
fi

missing=()
command -v kpackagetool6 >/dev/null || missing+=("kpackagetool6 (KDE Plasma 6 tools)")
[ -z "$QDBUS6_BIN" ]                && missing+=("qdbus6 (qt6-tools)")
command -v python3       >/dev/null || missing+=("python3")
python3 -c "import dbus" 2>/dev/null || missing+=("python3-dbus")
python3 -c "import gi"   2>/dev/null || missing+=("python3-gi")
command -v curl          >/dev/null || missing+=("curl")

soft_missing=()
command -v qrencode      >/dev/null || soft_missing+=("qrencode  (WiFi QR widget)")

if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing required dependencies:"
    for m in "${missing[@]}"; do echo "  · $m"; done
    echo
    echo "Debian/Ubuntu/Neon:  sudo apt install qt6-tools python3-dbus python3-gi curl"
    echo "Arch:                sudo pacman -S qt6-tools python-dbus python-gobject curl"
    echo "Fedora:              sudo dnf install qt6-qttools python3-dbus python3-gobject curl"
    echo
    echo "Fedora note: if qt6-qttools is installed but qdbus6 still isn't found,"
    echo "  it's likely at /usr/lib64/qt6/bin/qdbus6 (not on PATH by default)."
    echo "  Either re-run this script (it'll auto-symlink) or add to PATH:"
    echo "    echo 'export PATH=\"\$PATH:/usr/lib64/qt6/bin\"' >> ~/.bashrc"
    exit 1
fi

if [ ${#soft_missing[@]} -gt 0 ]; then
    echo "Optional dependencies missing (some widgets will degrade):"
    for m in "${soft_missing[@]}"; do echo "  · $m"; done
    echo "  Install hint:  sudo apt install qrencode"
    echo
fi

# ──────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────
install_widget() {
    local pkg="$1"
    [ -d "$pkg" ] || return 1
    local id=$(grep -oP '"Id"\s*:\s*"\K[^"]+' "$pkg/metadata.json" | head -1)
    local name=$(basename "$pkg")
    if [ -z "$id" ]; then
        echo "  · skip $name (no Id in metadata.json)"
        return 1
    fi
    if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -q "^$id$"; then
        kpackagetool6 -t Plasma/Applet -u "$pkg" >/dev/null
        echo "  · upgraded $name"
    else
        kpackagetool6 -t Plasma/Applet -i "$pkg" >/dev/null
        echo "  · installed $name"
    fi
}

install_screentime_extras() {
    local DAEMON_SRC="$PACKAGES/screen-time/daemon"
    [ -d "$DAEMON_SRC" ] || return 0
    echo "Installing Screen Time daemon..."
    mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
    install -m 0755 "$DAEMON_SRC/screentime-daemon.py" "$HOME/.local/bin/screentime-daemon"
    install -m 0644 "$DAEMON_SRC/screentime-daemon.service" "$HOME/.config/systemd/user/screentime-daemon.service"
    systemctl --user daemon-reload
    systemctl --user enable --now screentime-daemon.service >/dev/null 2>&1 || true
    echo "  · daemon enabled (systemctl --user status screentime-daemon)"

    local KWIN_SCRIPT_SRC="$ROOT/kwin-script"
    if [ -d "$KWIN_SCRIPT_SRC" ]; then
        if kpackagetool6 -t KWin/Script -l 2>/dev/null | grep -q "^screentime-tracker$"; then
            kpackagetool6 -t KWin/Script -u "$KWIN_SCRIPT_SRC" >/dev/null
        else
            kpackagetool6 -t KWin/Script -i "$KWIN_SCRIPT_SRC" >/dev/null
        fi
        kwriteconfig6 --file kwinrc --group Plugins --key screentime-trackerEnabled true 2>/dev/null || true
        "$QDBUS6_BIN" org.kde.KWin /KWin reconfigure 2>/dev/null || true
        echo "  · KWin tracker script enabled"
    fi
}

reload_plasma() {
    echo
    echo "Reloading plasmashell..."
    kquitapp6 plasmashell >/dev/null 2>&1 || true
    sleep 1
    kstart plasmashell >/dev/null 2>&1 &
    disown
    echo "[+] Done."
}

# ──────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────
ARG="${1:-}"

if [ -z "$ARG" ] || [ "$ARG" = "--all" ] || [ "$ARG" = "-a" ]; then
    echo "Installing all widgets..."
    for pkg in "$PACKAGES"/*/; do
        install_widget "$pkg" || true
    done
    install_screentime_extras

    echo
    echo "──────────────────────────────────────────────────────────────"
    echo "  lessplasma installed."
    echo "──────────────────────────────────────────────────────────────"
    echo
    echo "Right-click desktop → Add Widgets and search for any of:"
    for pkg in "$PACKAGES"/*/; do
        # KPlugin.Name specifically; the first "Name" in the file belongs to Authors.
        name=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["KPlugin"]["Name"])' "$pkg/metadata.json" 2>/dev/null)
        [ -n "$name" ] && echo "    · $name"
    done
    reload_plasma

elif [ -d "$PACKAGES/$ARG" ]; then
    install_widget "$PACKAGES/$ARG"
    if [ "$ARG" = "screen-time" ]; then
        install_screentime_extras
    fi
    reload_plasma

else
    echo "[!] Widget not found: $ARG"
    echo
    echo "Available widgets:"
    for pkg in "$PACKAGES"/*/; do
        echo "    · $(basename "$pkg")"
    done
    echo
    echo "Usage:"
    echo "  ./install.sh                  Install all widgets"
    echo "  ./install.sh --all | -a       Install all widgets"
    echo "  ./install.sh <widget>         Install a single widget"
    exit 1
fi
