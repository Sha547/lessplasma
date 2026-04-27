#!/usr/bin/env bash
# lessplasma installer
# Installs all widget plasmoids + Screen Time daemon (systemd user unit).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES="$ROOT/packages"

# ──────────────────────────────────────────────────────────────────────
# Dependency check
# ──────────────────────────────────────────────────────────────────────
missing=()
command -v kpackagetool6 >/dev/null || missing+=("kpackagetool6 (KDE Plasma 6 tools)")
command -v qdbus6        >/dev/null || missing+=("qdbus6 (qt6-tools)")
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
    exit 1
fi

if [ ${#soft_missing[@]} -gt 0 ]; then
    echo "Optional dependencies missing (some widgets will degrade):"
    for m in "${soft_missing[@]}"; do echo "  · $m"; done
    echo "  Install hint:  sudo apt install qrencode"
    echo
fi

# ──────────────────────────────────────────────────────────────────────
# Install plasmoids
# ──────────────────────────────────────────────────────────────────────
echo "Installing widgets..."

for pkg in "$PACKAGES"/*/; do
    [ -d "$pkg" ] || continue
    id=$(grep -oP '"Id"\s*:\s*"\K[^"]+' "$pkg/metadata.json" | head -1)
    name=$(basename "$pkg")
    if [ -z "$id" ]; then
        echo "  · skip $name (no Id in metadata.json)"
        continue
    fi
    if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -q "^$id$"; then
        kpackagetool6 -t Plasma/Applet -u "$pkg" >/dev/null
        echo "  · upgraded $name"
    else
        kpackagetool6 -t Plasma/Applet -i "$pkg" >/dev/null
        echo "  · installed $name"
    fi
done

# ──────────────────────────────────────────────────────────────────────
# Screen Time daemon — needs binary + systemd unit + KWin script
# ──────────────────────────────────────────────────────────────────────
DAEMON_SRC="$PACKAGES/screen-time/daemon"
if [ -d "$DAEMON_SRC" ]; then
    echo "Installing Screen Time daemon..."
    mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
    install -m 0755 "$DAEMON_SRC/screentime-daemon.py" "$HOME/.local/bin/screentime-daemon"
    install -m 0644 "$DAEMON_SRC/screentime-daemon.service" "$HOME/.config/systemd/user/screentime-daemon.service"
    systemctl --user daemon-reload
    systemctl --user enable --now screentime-daemon.service >/dev/null 2>&1 || true
    echo "  · daemon enabled (systemctl --user status screentime-daemon)"

    KWIN_SCRIPT_SRC="$ROOT/kwin-script"
    if [ -d "$KWIN_SCRIPT_SRC" ]; then
        if kpackagetool6 -t KWin/Script -l 2>/dev/null | grep -q "^screentime-tracker$"; then
            kpackagetool6 -t KWin/Script -u "$KWIN_SCRIPT_SRC" >/dev/null
        else
            kpackagetool6 -t KWin/Script -i "$KWIN_SCRIPT_SRC" >/dev/null
        fi
        kwriteconfig6 --file kwinrc --group Plugins --key screentime-trackerEnabled true 2>/dev/null || true
        qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
        echo "  · KWin tracker script enabled"
    fi
fi

echo
echo "──────────────────────────────────────────────────────────────"
echo "  lessplasma installed."
echo "──────────────────────────────────────────────────────────────"
echo
echo "Reload Plasma to register the new widgets:"
echo "    kquitapp6 plasmashell && kstart plasmashell"
echo
echo "Then right-click your desktop → Add Widgets and search for any of:"
for pkg in "$PACKAGES"/*/; do
    name=$(grep -oP '"Name"\s*:\s*"\K[^"]+' "$pkg/metadata.json" | head -1)
    [ -n "$name" ] && echo "    · $name"
done
