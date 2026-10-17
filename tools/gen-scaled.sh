#!/bin/sh
# 生成 Linux/Quickshell 用的预缩放立绘(高分辨率 Lanczos 缩放,避免 QML/GPU 直接缩小发虚)
# 用法: tools/gen-scaled.sh [尺寸...]
# 需要 ImageMagick(magick)。生成的 assets/scaled/ 已提交,普通用户不需要运行。
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
OUT="$ROOT/assets/scaled"
SIZES="${*:-102 136 170 204 255 340 425 510 640 850}"

command -v magick >/dev/null || { echo "需要 ImageMagick(magick)" >&2; exit 1; }
mkdir -p "$OUT"

gen() {
    src="$1"; base="$2"
    [ -f "$src" ] || return 0
    for s in $SIZES; do
        magick "$src" -filter Lanczos -resize "${s}x${s}" -strip "$OUT/$base@$s.png"
    done
}
gen "$ROOT/assets/DSniang1.png" DSniang1
gen "$ROOT/assets/characters/xiaoke.png" xiaoke
gen "$ROOT/assets/characters/gptniang.png" gptniang
echo "完成: $OUT"
