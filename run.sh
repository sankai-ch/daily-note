#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/Riji"
APP="日计.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Riji"
cp Support/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null
killall Riji >/dev/null 2>&1 || true
open "$APP"
echo "已打开日计。看屏幕最上方右侧，时钟图标旁边。"
