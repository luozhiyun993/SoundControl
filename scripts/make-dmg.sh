#!/bin/bash
# 打包 build/SoundControl-<版本>.dmg：内含 App 和"应用程序"文件夹的快捷方式，拖进去即可安装。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build-app.sh"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT/Resources/Info.plist")
DMG="$ROOT/build/SoundControl-$VERSION.dmg"
STAGING="$ROOT/build/dmg"

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$ROOT/build/SoundControl.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "SoundControl" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGING"

echo "已生成 $DMG"
