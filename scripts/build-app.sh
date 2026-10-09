#!/bin/bash
# 编译并打包 build/SoundControl.app。见 docs/adr/0002。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CERT_NAME="SoundControl Dev"
APP="$ROOT/build/SoundControl.app"

cd "$ROOT"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/SoundControl"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/SoundControl"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# 由 Resources/AppIcon.png（scripts/make-icon.swift 生成）制作 .icns。
ICONSET="$ROOT/build/AppIcon.iconset"
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z $size $size "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

if security find-certificate -c "$CERT_NAME" >/dev/null 2>&1; then
    codesign --force --sign "$CERT_NAME" "$APP"
else
    echo "警告：未找到证书 \"$CERT_NAME\"，改用临时签名（每次编译后需重新授权）。"
    echo "      运行 scripts/create-signing-cert.sh 可创建证书。"
    codesign --force --sign - "$APP"
fi

echo "已生成 $APP"
