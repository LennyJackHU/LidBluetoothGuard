#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/.build/release/LidBluetoothGuard.app"
DIST="$ROOT/dist"
ZIP="$DIST/LidBluetoothGuard.zip"

"$ROOT/Scripts/package-app.sh"

mkdir -p "$DIST"

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    codesign \
        --force \
        --options runtime \
        --timestamp \
        --sign "$DEVELOPER_ID_APPLICATION" \
        "$APP"

    codesign --verify --deep --strict --verbose=2 "$APP"
else
    echo "Skipping Developer ID signing because DEVELOPER_ID_APPLICATION is not set."
fi

rm -f "$ZIP"
ditto -c -k --norsrc --keepParent "$APP" "$ZIP"

if [[ "${NOTARIZE:-0}" == "1" ]]; then
    : "${APPLE_ID:?Set APPLE_ID to notarize.}"
    : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID to notarize.}"
    : "${APP_SPECIFIC_PASSWORD:?Set APP_SPECIFIC_PASSWORD to notarize.}"

    xcrun notarytool submit "$ZIP" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APP_SPECIFIC_PASSWORD" \
        --wait

    xcrun stapler staple "$APP"
    xcrun stapler validate "$APP"
    spctl --assess --type execute --verbose "$APP"

    rm -f "$ZIP"
    ditto -c -k --norsrc --keepParent "$APP" "$ZIP"
fi

echo "Release package: $ZIP"
