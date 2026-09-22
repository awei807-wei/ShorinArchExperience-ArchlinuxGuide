#!/usr/bin/env bash

set -uo pipefail

log() {
    printf '[wallpaper-changed] %s\n' "$*" >&2
}

if [ "$#" -ne 1 ]; then
    log "用法: $0 WALLPAPER"
    exit 2
fi

WALLPAPER="$1"
if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
    log "壁纸文件不存在或不可读: $WALLPAPER"
    exit 2
fi

if [ -z "${HOME:-}" ]; then
    log "HOME 未设置，无法更新头像和壁纸状态"
    exit 2
fi

AVATAR_PATH="$HOME/.curr_wall_static.jpg"
STATE_DIR="$HOME/.cache/quickshell"
STATE_PATH="$STATE_DIR/wallpaper-state.json"
AVATAR_TMP=""
STATE_TMP=""
OVERALL_STATUS=0

cleanup() {
    if [ -n "$AVATAR_TMP" ]; then
        rm -f -- "$AVATAR_TMP"
    fi
    if [ -n "$STATE_TMP" ]; then
        rm -f -- "$STATE_TMP"
    fi
}
trap cleanup EXIT HUP INT TERM

update_avatar_and_state() {
    local image_command=""

    if command -v magick >/dev/null 2>&1; then
        image_command="magick"
    elif command -v convert >/dev/null 2>&1; then
        image_command="convert"
    else
        log "未找到 ImageMagick（magick/convert），保留旧头像"
        return 1
    fi

    AVATAR_TMP=$(mktemp "$HOME/.curr_wall_static.tmp.XXXXXX.jpg") || {
        log "无法在 HOME 中创建头像临时文件，保留旧头像"
        return 1
    }

    if ! "$image_command" "${WALLPAPER}[0]" \
        -auto-orient \
        -thumbnail '512x512^' \
        -gravity center \
        -extent 512x512 \
        -background white \
        -alpha remove \
        -alpha off \
        -colorspace sRGB \
        -strip \
        -quality 88 \
        "$AVATAR_TMP"; then
        log "头像缩略图生成失败，保留旧头像"
        return 1
    fi

    if [ ! -s "$AVATAR_TMP" ]; then
        log "头像缩略图为空，保留旧头像"
        return 1
    fi

    if ! mv -f -- "$AVATAR_TMP" "$AVATAR_PATH"; then
        log "头像原子替换失败，保留旧头像"
        return 1
    fi
    AVATAR_TMP=""

    if ! mkdir -p -- "$STATE_DIR"; then
        log "无法创建状态目录: $STATE_DIR"
        return 1
    fi

    STATE_TMP=$(mktemp "$STATE_DIR/.wallpaper-state.XXXXXX.json") || {
        log "无法创建壁纸状态临时文件"
        return 1
    }

    if ! python3 - "$WALLPAPER" "$AVATAR_PATH" "$STATE_TMP" <<'PY'
import json
import sys
from datetime import datetime, timezone

source, avatar, output = sys.argv[1:4]
payload = {
    "source": source,
    "avatar": avatar,
    "updatedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
}
with open(output, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, ensure_ascii=False, separators=(",", ":"))
    handle.write("\n")
PY
    then
        log "壁纸状态 JSON 写入失败"
        return 1
    fi

    if ! mv -f -- "$STATE_TMP" "$STATE_PATH"; then
        log "壁纸状态原子替换失败"
        return 1
    fi
    STATE_TMP=""
    return 0
}

if ! update_avatar_and_state; then
    OVERALL_STATUS=1
fi

if ! "$HOME/.config/scripts/matugen-update.sh" "$WALLPAPER"; then
    log "Matugen 更新失败"
    OVERALL_STATUS=1
fi

sleep 1

if ! "$HOME/.config/scripts/niri_set_overview_blur_dark_bg.sh" "$WALLPAPER"; then
    log "Niri overview 模糊背景更新失败"
    OVERALL_STATUS=1
fi

exit "$OVERALL_STATUS"
