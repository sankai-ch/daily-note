#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/Riji"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/日计.app"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Riji"
cp Support/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

ln -s /Applications "$STAGE/Applications"
mkdir -p dist
DMG="dist/Riji-${VERSION}.dmg"
rm -f "$DMG"
hdiutil create -volname "日计 ${VERSION}" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
echo "$DMG"
