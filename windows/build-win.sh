#!/bin/sh
# 构建 Windows 11 便携版 zip(Linux/macOS/WSL 均可运行)
# 用法: ./build-win.sh [electron版本]
set -eu

HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$HERE/.." && pwd)"
VER="${1:-44.8.0}"
NAME="DSH-Pet-1.1.0-win32-x64"
CACHE="$HERE/.cache"
DIST="$HERE/dist"
ZIP="$CACHE/electron-v$VER-win32-x64.zip"

mkdir -p "$CACHE" "$DIST"

if [ ! -f "$ZIP" ]; then
    echo "下载 Electron v$VER ..."
    curl -fL --retry 3 --connect-timeout 15 \
        -o "$ZIP" \
        "https://cdn.npmmirror.com/binaries/electron/$VER/electron-v$VER-win32-x64.zip" \
        || curl -fL --retry 3 --connect-timeout 15 \
        -o "$ZIP" \
        "https://github.com/electron/electron/releases/download/v$VER/electron-v$VER-win32-x64.zip"
fi

OUT="$DIST/$NAME"
rm -rf "$OUT"
mkdir -p "$OUT"
unzip -q "$ZIP" -d "$OUT"

# Electron 默认应用替换成我们的 app
rm -f "$OUT/resources/default_app.asar"
mkdir -p "$OUT/resources/app/renderer" "$OUT/resources/assets"
cp "$HERE/package.json" "$HERE/main.js" "$HERE/preload.js" "$HERE/shared.js" "$OUT/resources/app/"
cp "$HERE/renderer/"* "$OUT/resources/app/renderer/"
cp -r "$ROOT/assets/." "$OUT/resources/assets/"
# Linux 专用预缩放图,Windows/Chromium 不需要
rm -rf "$OUT/resources/assets/scaled"
if [ -f "$OUT/electron.exe" ]; then mv "$OUT/electron.exe" "$OUT/DSH-Pet.exe"; fi

# 协议与说明随包分发(Electron 自带的 LICENSE / LICENSES.chromium.html 保留)
if [ -d "$ROOT/licenses" ]; then cp -r "$ROOT/licenses" "$OUT/licenses"; fi
mkdir -p "$OUT/licenses"
cp "$ROOT/LICENSE" "$OUT/licenses/LICENSE-DSH-PET.txt" 2>/dev/null || true
cp "$ROOT/LICENSE-ARTWORK.md" "$OUT/" 2>/dev/null || true
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$OUT/" 2>/dev/null || true
cp "$ROOT/windows/README-Windows.md" "$OUT/README.md" 2>/dev/null || true

cd "$DIST"
rm -f "$NAME.zip"
zip -qr "$NAME.zip" "$NAME"
echo "完成: $DIST/$NAME.zip"
