#!/bin/bash
# 编译并安装到 ~/Applications，然后启动。开机自启动依赖固定的安装位置。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/Applications/SoundControl.app"

"$ROOT/scripts/build-app.sh"

pkill -x SoundControl 2>/dev/null && sleep 1 || true
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
cp -R "$ROOT/build/SoundControl.app" "$DEST"
# 让 Finder / Dock 刷新图标缓存。
touch "$DEST"

open "$DEST"
echo "已安装到 $DEST"
