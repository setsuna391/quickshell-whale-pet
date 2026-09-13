#!/bin/sh
# DSH 小鲸鱼桌面宠物启动器
# 用法: run.sh [start|stop|restart]
DIR="$HOME/Documents/Project/quickshell-pet"
# 分数缩放(如 1.2x)下按原生分辨率渲染,避免合成器放大导致字体发虚
export QT_SCALE_FACTOR_ROUNDING_POLICY=PassThrough
export QT_ENABLE_HIGHDPI_SCALING=1
# 兼容两种进程形式: quickshell -p DIR / AppImage -p DIR
PAT="(-|/)p $DIR([[:space:]]|$)"

case "${1:-start}" in
    start)
        pgrep -f "$PAT" >/dev/null 2>&1 || exec quickshell -p "$DIR"
        ;;
    stop)
        pkill -f "$PAT"
        ;;
    restart)
        pkill -f "$PAT"
        sleep 0.5
        exec quickshell -p "$DIR"
        ;;
    *)
        echo "用法: run.sh [start|stop|restart]" >&2
        exit 1
        ;;
esac
