#!/bin/zsh
set -euo pipefail

ROOT="/Users/eowyn/WorkBuddy/2026-11-18-08-33-39/MacroSeek"
SRC="$ROOT/Sources"
RES="$ROOT/Resources"
BUILD="$ROOT/build"
APP="$BUILD/MacroSeek.app"

echo "==> 清理旧包"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> swiftc 编译（不依赖 Xcode 工程）"
swiftc -O \
  "$SRC/main.swift" \
  "$SRC/Settings.swift" \
  "$SRC/HotkeyManager.swift" \
  "$SRC/SearchEngine.swift" \
  "$SRC/SettingsWindowController.swift" \
  "$SRC/MainPanelController.swift" \
  -o "$APP/Contents/MacOS/MacroSeek" \
  -framework AppKit \
  -framework Carbon \
  -framework ServiceManagement \
  -framework Quartz

echo "==> 拷贝资源"
cp "$RES/Info.plist" "$APP/Contents/Info.plist"
cp "$RES/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$RES/MenuIcon.png" "$APP/Contents/Resources/MenuIcon.png"
cp "$RES/MenuIcon@2x.png" "$APP/Contents/Resources/MenuIcon@2x.png"

echo "==> ad-hoc 签名（资源已就位，签名放最后）"
codesign --force --deep --sign - "$APP"

echo "==> 完成: $APP"
