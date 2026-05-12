#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/.build/release/LidBluetoothGuard.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

export CLANG_MODULE_CACHE_PATH="$ROOT/.build/ModuleCache"

cd "$ROOT"
swift build -c release

mkdir -p "$MACOS" "$RESOURCES"
cp "$ROOT/.build/release/LidBluetoothGuard" "$MACOS/LidBluetoothGuard"
chmod +x "$MACOS/LidBluetoothGuard"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>LidBluetoothGuard</string>
    <key>CFBundleIdentifier</key>
    <string>local.lid-bluetooth-guard</string>
    <key>CFBundleName</key>
    <string>Lid Bluetooth Guard</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>Used to turn Bluetooth off when the MacBook lid closes.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"

echo "Built $APP"
