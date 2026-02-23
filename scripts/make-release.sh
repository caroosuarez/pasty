#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$ROOT_DIR/release"
APP_PATH="$DIST_DIR/Pasty.app"
ZIP_PATH="$RELEASE_DIR/Pasty-macOS.zip"
DMG_PATH="$RELEASE_DIR/Pasty-macOS.dmg"

MAKE_DMG=true
if [[ "${1:-}" == "--no-dmg" ]]; then
    MAKE_DMG=false
fi

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/build-app.sh"

mkdir -p "$RELEASE_DIR"
rm -f "$ZIP_PATH" "$DMG_PATH"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Created: $ZIP_PATH"

if [[ "$MAKE_DMG" == true ]]; then
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT

    cp -R "$APP_PATH" "$TMP_DIR/Pasty.app"

    hdiutil create \
        -volname "Pasty" \
        -srcfolder "$TMP_DIR" \
        -ov \
        -format UDZO \
        "$DMG_PATH" >/dev/null

    echo "Created: $DMG_PATH"
else
    echo "Skipped DMG (--no-dmg)."
fi

echo "Release files are in: $RELEASE_DIR"
