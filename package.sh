#!/usr/bin/env bash
# lessplasma: bundle each widget into a distributable .plasmoid file.
# Output goes into packaged/<widget>-<version>.plasmoid

set -e

PACKAGE_DIR="packaged"
PACKAGES_SRC="packages"

extract() {
    grep -oP "\"$1\"\\s*:\\s*\"\\K[^\"]+" "$2" | head -1
}

package_widget() {
    local NAME="$1"
    local DIR="$PACKAGES_SRC/$NAME"
    local META="$DIR/metadata.json"

    if [[ ! -f "$META" ]]; then
        echo "[!] $NAME: metadata.json not found"
        return 1
    fi

    echo
    echo "================================"
    echo "[*] Packaging: $NAME"
    echo "================================"

    local ID=$(extract "Id" "$META")
    local VERSION=$(extract "Version" "$META")

    if [[ -z "$ID" ]]; then
        echo "[!] $NAME: invalid Id in metadata.json"
        return 1
    fi

    local OUT_NAME="$NAME"
    [[ -n "$VERSION" ]] && OUT_NAME="$NAME-$VERSION"
    local OUT_FILE="$PACKAGE_DIR/$OUT_NAME.plasmoid"

    mkdir -p "$PACKAGE_DIR"
    rm -f "$OUT_FILE"

    local TMP=$(mktemp -d)
    trap "rm -rf $TMP" RETURN

    echo "[*] Copying widget files..."
    # Follow symlinks; exclude daemon/ (Screen Time only, not part of plasmoid spec).
    tar -C "$DIR" -chf - --exclude=daemon . | tar -C "$TMP" -xf -

    echo "[*] Removing dev cruft..."
    find "$TMP" \( -name "*.swp" -o -name "*.swo" -o -name "*~" \
                  -o -name ".DS_Store" -o -name "Thumbs.db" \) -delete 2>/dev/null || true

    local ABS_OUT=$(realpath "$OUT_FILE")
    pushd "$TMP" > /dev/null
    zip -q -r "$ABS_OUT" .
    popd > /dev/null

    echo "[+] $ID v$VERSION → $ABS_OUT  ($(du -h "$OUT_FILE" | cut -f1))"
    return 0
}

if [[ "$1" == "--all" || "$1" == "-a" ]]; then
    echo "[*] Packaging all widgets..."
    WIDGETS=($(ls -d $PACKAGES_SRC/*/ 2>/dev/null | xargs -n 1 basename))

    if [[ ${#WIDGETS[@]} -eq 0 ]]; then
        echo "[!] No widgets found in $PACKAGES_SRC/"
        exit 1
    fi

    OK=()
    FAIL=()
    for w in "${WIDGETS[@]}"; do
        if package_widget "$w"; then OK+=("$w"); else FAIL+=("$w"); fi
    done

    echo
    echo "================================"
    echo "[*] Summary"
    echo "================================"
    echo "[+] Packaged ${#OK[@]}:"
    for w in "${OK[@]}"; do echo "    ✓ $w"; done
    if [[ ${#FAIL[@]} -gt 0 ]]; then
        echo "[!] Failed ${#FAIL[@]}:"
        for w in "${FAIL[@]}"; do echo "    ✗ $w"; done
    fi
    echo
    echo "[+] All packages saved to: $(realpath $PACKAGE_DIR)"

elif [[ -n "$1" && -d "$PACKAGES_SRC/$1" ]]; then
    package_widget "$1"
    echo
    echo "[+] Done."
else
    [[ -n "$1" ]] && echo "[!] Widget not found: $1"
    echo "[+] Available widgets:"
    ls "$PACKAGES_SRC"
    echo
    echo "Usage:"
    echo "  ./package.sh <widget>          Package one widget"
    echo "  ./package.sh --all | -a        Package all widgets"
    exit 1
fi
