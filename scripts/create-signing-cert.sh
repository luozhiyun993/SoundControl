#!/bin/bash
# 在登录钥匙串中创建自签名代码签名证书（只需运行一次）。
# 用固定证书签名，重新编译后 macOS 才会保留"系统音频录制"授权。见 docs/adr/0002。
set -euo pipefail

CERT_NAME="SoundControl Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$CERT_NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "证书 \"$CERT_NAME\" 已存在，无需重复创建。"
    exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.conf" <<CONF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $CERT_NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CONF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -config "$TMP/cert.conf" -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -name "$CERT_NAME" -out "$TMP/cert.p12" -passout pass:soundcontrol

security import "$TMP/cert.p12" -k "$KEYCHAIN" -P soundcontrol -T /usr/bin/codesign
echo "已创建证书 \"$CERT_NAME\"。"
