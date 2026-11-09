#!/bin/sh
# DSH 小鲸鱼桌面宠物启动器
# 用法: run.sh [start|stop|restart]
DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# 分数缩放(如 1.2x)下按原生分辨率渲染,避免合成器放大导致字体发虚
export QT_SCALE_FACTOR_ROUNDING_POLICY=PassThrough
export QT_ENABLE_HIGHDPI_SCALING=1
# 兼容两种进程形式: quickshell -p DIR / AppImage -p DIR
ESCAPED_DIR=$(printf '%s\n' "$DIR" | sed 's/[][\\.^$*+?(){}|]/\\&/g')
PAT="(-|/)p $ESCAPED_DIR([[:space:]]|$)"
# 定位 quickshell: 优先 PATH, 否则回退到 caelestia 依赖的 nix store 路径
QS="$(command -v quickshell 2>/dev/null || true)"
[ -z "$QS" ] && QS="$(ls -d /nix/store/*-quickshell-wrapped-*/bin/quickshell 2>/dev/null | sort -V | tail -n1)"

case "${1:-start}" in
    start)
        [ -n "$QS" ] || { echo "找不到 quickshell,请先安装 Quickshell" >&2; exit 127; }
        pgrep -f "$PAT" >/dev/null 2>&1 || exec "$QS" -p "$DIR"
        ;;
    stop)
        pkill -f "$PAT"
        ;;
    restart)
        [ -n "$QS" ] || { echo "找不到 quickshell,请先安装 Quickshell" >&2; exit 127; }
        pkill -f "$PAT"
        sleep 0.5
        exec "$QS" -p "$DIR"
        ;;
    *)
        echo "用法: run.sh [start|stop|restart]" >&2
        exit 1
        ;;
esac
