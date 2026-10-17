#!/bin/sh
# DSH 小鲸鱼桌面宠物 · 快捷换模型
# 用法: model.sh [list|next|<模型名或路径>]
#   model.sh                  列出当前模型和所有可用模型
#   model.sh next             切换到下一个
#   model.sh xiaoke           按名字模糊匹配切换
#   model.sh characters/xiaoke.png
#   model.sh default          换回小鲸鱼

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

asset_models() {
    find "$DIR/assets" -maxdepth 2 -type f \
        \( -iname '*.png' -o -iname '*.webp' -o -iname '*.jpg' -o -iname '*.jpeg' \) \
        ! -path "$DIR/assets/scaled/*" \
        | sed "s|^$DIR/assets/||" | sort
}

# config.json 里的 models 数组优先,没有就扫描 assets
list_models() {
    m=$(python3 -c 'import json,os
try:
    models = json.load(open(os.path.expanduser("~/.config/dsh-pet/config.json"))).get("models") or []
    print("\n".join(x for x in models if isinstance(x, str) and x))
except Exception:
    pass' 2>/dev/null)
    if [ -n "$m" ]; then
        printf '%s\n' "$m"
    else
        asset_models
    fi
}

current_model() {
    m=""
    if command -v qs >/dev/null 2>&1; then
        m=$(qs ipc -p "$DIR" call dsh-pet getModel 2>/dev/null)
    fi
    if [ -z "$m" ]; then
        m=$(python3 -c 'import json,os
try:
    print(json.load(open(os.path.expanduser("~/.config/dsh-pet/config.json"))).get("model",""))
except Exception:
    pass' 2>/dev/null)
    fi
    echo "$m"
}

resolve_model() {
    case "$1" in
        default|whale|DSniang1|DSniang1.png|鲸鱼|小鲸鱼) echo "DSniang1.png"; return 0 ;;
        xiaoke|xiaoke1|xiaoke1.png|小克) echo "characters/xiaoke.png"; return 0 ;;
        gptniang|gptniang1|gptniang1.png|gpt|GPT娘|gpt娘) echo "characters/gptniang.png"; return 0 ;;
    esac
    [ -f "$DIR/assets/$1" ] && { echo "$1"; return 0; }
    [ -f "$1" ] && { echo "$1"; return 0; }
    for m in $(list_models); do
        b=${m##*/}
        [ "$m" = "$1" ] && { echo "$m"; return 0; }
        [ "$b" = "$1" ] && { echo "$m"; return 0; }
        [ "${b%.*}" = "$1" ] && { echo "$m"; return 0; }
    done
    return 1
}

persist_model() {
    python3 - "$1" <<'PY' >/dev/null 2>&1
import json, os, sys
p = os.path.expanduser("~/.config/dsh-pet/config.json")
j = json.load(open(p))
j["model"] = sys.argv[1]
open(p, "w").write(json.dumps(j, ensure_ascii=False, separators=(",", ":")))
PY
}

apply_model() {
    new="$1"
    if persist_model "$new"; then
        echo "已写入 config.json: $new"
    else
        echo "config.json 不可写(可能由 Nix 管理),仅本次运行生效"
    fi
    if command -v qs >/dev/null 2>&1; then
        out=$(qs ipc -p "$DIR" call dsh-pet setModel "$new" 2>/dev/null)
        [ -n "$out" ] && echo "宠物已切换: $out"
    fi
}

case "${1:-list}" in
    list|ls)
        cur=$(current_model)
        echo "当前: ${cur:-未知}"
        echo "可用:"
        list_models | while IFS= read -r m; do
            if [ "$m" = "$cur" ]; then echo "  * $m"; else echo "    $m"; fi
        done
        ;;
    next|n)
        cur=$(current_model)
        case "$cur" in "$DIR"/assets/*) cur=${cur#"$DIR"/assets/} ;; esac
        next=""; first=""; found=0
    for m in $(list_models) $(asset_models); do
            [ -z "$first" ] && first="$m"
            if [ "$found" = 1 ]; then next="$m"; break; fi
            [ "$m" = "$cur" ] && found=1
        done
        [ -z "$next" ] && next="$first"
        [ -n "$next" ] || { echo "assets 里没有可用图片" >&2; exit 1; }
        apply_model "$next"
        ;;
    -h|--help|help)
        sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
        ;;
    *)
        new=$(resolve_model "$1") || {
            echo "找不到模型: $1" >&2
            echo "可用模型:" >&2
            list_models | sed 's/^/  /' >&2
            exit 1
        }
        apply_model "$new"
        ;;
esac
