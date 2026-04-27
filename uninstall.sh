#!/usr/bin/env bash
# lessplasma uninstaller
# Removes all plasmoids + Screen Time daemon + KWin script.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES="$ROOT/packages"

echo "Removing widgets..."
for pkg in "$PACKAGES"/*/; do
    [ -d "$pkg" ] || continue
    id=$(grep -oP '"Id"\s*:\s*"\K[^"]+' "$pkg/metadata.json" | head -1)
    [ -z "$id" ] && continue
    kpackagetool6 -t Plasma/Applet -r "$id" >/dev/null 2>&1 || true
    echo "  · removed $(basename "$pkg")"
done

echo "Stopping Screen Time daemon..."
systemctl --user disable --now screentime-daemon.service >/dev/null 2>&1 || true
rm -f "$HOME/.config/systemd/user/screentime-daemon.service"
rm -f "$HOME/.local/bin/screentime-daemon"
systemctl --user daemon-reload || true

echo "Removing KWin tracker script..."
kpackagetool6 -t KWin/Script -r screentime-tracker >/dev/null 2>&1 || true
kwriteconfig6 --file kwinrc --group Plugins --key screentime-trackerEnabled false 2>/dev/null || true
qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true

echo
echo "Done. Data kept at:"
echo "    ~/.local/share/plasma-screentime/   (Screen Time database)"
echo "    ~/.cache/plasma-wifi-qr/             (WiFi QR cache)"
echo
echo "Delete manually if you want them gone."
