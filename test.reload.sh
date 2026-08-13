#!/usr/bin/env bash
# Quick preview of a single widget in plasmoidviewer6 without touching plasmashell.
# Usage:  ./test.reload.sh <widget-name>

set -e

if [[ -z "$1" ]]; then
    echo "Usage:  $0 <widget-name>"
    echo
    echo "Available widgets:"
    ls packages
    exit 1
fi

if [[ ! -d "packages/$1" ]]; then
    echo "[!] Widget not found: $1"
    exit 1
fi

# Named plasmoidviewer6 on some distros, plain plasmoidviewer on others (Neon, Arch).
VIEWER=$(command -v plasmoidviewer6 || command -v plasmoidviewer || true)

if [[ -z "$VIEWER" ]]; then
    echo "[!] plasmoidviewer not found. Install plasma-sdk"
    exit 1
fi

"$VIEWER" -a "packages/$1"
