#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$ROOT_DIR/dist/All Toast for Mac.app"
EXECUTABLE="$APP_DIR/Contents/MacOS/all-toast-for-mac"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"

mkdir -p "$ROOT_DIR/.build/release" "$ROOT_DIR/.build/module-cache"
swiftc \
  -module-cache-path "$ROOT_DIR/.build/module-cache" \
  -sdk "$SDK_PATH" \
  -O \
  -framework AppKit \
  "$ROOT_DIR/Sources/AllToastForMac/main.swift" \
  -o "$ROOT_DIR/.build/release/all-toast-for-mac"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$ROOT_DIR/.build/release/all-toast-for-mac" "$EXECUTABLE"
chmod +x "$EXECUTABLE"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>all-toast-for-mac</string>
  <key>CFBundleIdentifier</key>
  <string>com.tootony0824.AllToastForMac</string>
  <key>CFBundleName</key>
  <string>All Toast for Mac</string>
  <key>CFBundleDisplayName</key>
  <string>All Toast for Mac</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

echo "$APP_DIR"
