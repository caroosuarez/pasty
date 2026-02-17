#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/Pasty.app"
EXECUTABLE="$ROOT_DIR/.build/release/Pasty"
ICON_PATH="$ROOT_DIR/assets/Pasty.icns"

cd "$ROOT_DIR"

if [[ ! -f "$ICON_PATH" ]]; then
    "$ROOT_DIR/scripts/generate-icon.sh"
fi

swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/Pasty"
chmod +x "$APP_DIR/Contents/MacOS/Pasty"
cp "$ICON_PATH" "$APP_DIR/Contents/Resources/Pasty.icns"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Pasty</string>
    <key>CFBundleExecutable</key>
    <string>Pasty</string>
    <key>CFBundleIdentifier</key>
    <string>com.carosuarez.pasty</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIconFile</key>
    <string>Pasty.icns</string>
    <key>CFBundleName</key>
    <string>Pasty</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "Built app bundle: $APP_DIR"
