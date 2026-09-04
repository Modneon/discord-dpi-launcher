#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
APP_NAME="Discord DPI Launcher"
APP_DIR="$SCRIPT_DIR/dist/$APP_NAME.app"
BUILD_DIR="$SCRIPT_DIR/.build"

swift build \
  --package-path "$SCRIPT_DIR" \
  --scratch-path "$BUILD_DIR" \
  -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/release/DiscordDPILauncher" "$APP_DIR/Contents/MacOS/DiscordDPILauncher"
cp "$SCRIPT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
codesign --force --deep --sign - "$APP_DIR"

echo "Hazır: $APP_DIR"
