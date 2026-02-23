#!/usr/bin/env bash
set -euo pipefail

REPO="${PASTY_REPO:-caroosuarez/pasty}"
APP_NAME="Pasty.app"
ZIP_NAME="Pasty-macOS.zip"
DOWNLOAD_URL="https://github.com/${REPO}/releases/latest/download/${ZIP_NAME}"
INSTALL_DIR="/Applications"
TARGET_PATH="${INSTALL_DIR}/${APP_NAME}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading latest Pasty from: $DOWNLOAD_URL"
curl -fL "$DOWNLOAD_URL" -o "$TMP_DIR/$ZIP_NAME"

ditto -x -k "$TMP_DIR/$ZIP_NAME" "$TMP_DIR"

if [[ ! -d "$TMP_DIR/$APP_NAME" ]]; then
    echo "Could not find $APP_NAME inside downloaded zip."
    exit 1
fi

rm -rf "$TARGET_PATH"

if ! cp -R "$TMP_DIR/$APP_NAME" "$INSTALL_DIR/" 2>/dev/null; then
    echo "Need admin permission to install to /Applications."
    sudo cp -R "$TMP_DIR/$APP_NAME" "$INSTALL_DIR/"
fi

xattr -dr com.apple.quarantine "$TARGET_PATH" >/dev/null 2>&1 || true

open -a "$TARGET_PATH"

echo "Installed and opened: $TARGET_PATH"
