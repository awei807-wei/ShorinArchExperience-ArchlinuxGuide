#!/usr/bin/env bash

set -uo pipefail

usage() {
    printf '用法: %s {load|refresh} YEAR\n' "$0" >&2
}

if [ "$#" -ne 2 ]; then
    usage
    exit 2
fi

MODE="$1"
YEAR="$2"

case "$MODE" in
    load|refresh) ;;
    *)
        usage
        exit 2
        ;;
esac

if [[ ! "$YEAR" =~ ^[0-9]{4}$ ]]; then
    printf '年份必须是四位数字: %s\n' "$YEAR" >&2
    exit 2
fi

if [ -n "${XDG_CACHE_HOME:-}" ]; then
    CACHE_BASE="$XDG_CACHE_HOME"
elif [ -n "${HOME:-}" ]; then
    CACHE_BASE="$HOME/.cache"
else
    printf 'HOME 与 XDG_CACHE_HOME 均未设置\n' >&2
    exit 2
fi

CACHE_DIR="$CACHE_BASE/quickshell/holidays"
CACHE_FILE="$CACHE_DIR/$YEAR.json"
TEMP_FILE=""
PRIMARY_URL="https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/$YEAR.json"
FALLBACK_URL="https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/$YEAR.json"
MAX_AGE_SECONDS=$((7 * 24 * 60 * 60))

cleanup() {
    if [ -n "$TEMP_FILE" ]; then
        rm -f -- "$TEMP_FILE"
    fi
}
trap cleanup EXIT HUP INT TERM

validate_json() {
    local file_path="$1"
    python3 - "$file_path" "$YEAR" <<'PY'
import datetime as dt
import json
import re
import sys

path = sys.argv[1]
expected_year = int(sys.argv[2])

try:
    with open(path, "r", encoding="utf-8") as handle:
        payload = json.load(handle)
except (OSError, UnicodeError, json.JSONDecodeError):
    raise SystemExit(1)

if not isinstance(payload, dict):
    raise SystemExit(1)
year = payload.get("year")
if isinstance(year, bool) or not isinstance(year, int) or year != expected_year:
    raise SystemExit(1)

days = payload.get("days")
if not isinstance(days, list):
    raise SystemExit(1)

seen = set()
for item in days:
    if not isinstance(item, dict):
        raise SystemExit(1)
    name = item.get("name")
    date_text = item.get("date")
    is_off_day = item.get("isOffDay")
    if not isinstance(name, str) or not name.strip():
        raise SystemExit(1)
    if not isinstance(date_text, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", date_text):
        raise SystemExit(1)
    try:
        parsed_date = dt.date.fromisoformat(date_text)
    except ValueError:
        raise SystemExit(1)
    if parsed_date.year != expected_year or date_text in seen:
        raise SystemExit(1)
    seen.add(date_text)
    if not isinstance(is_off_day, bool):
        raise SystemExit(1)
PY
}

cache_is_fresh() {
    local file_path="$1"
    python3 - "$file_path" "$MAX_AGE_SECONDS" <<'PY'
import os
import sys
import time

try:
    age = max(0.0, time.time() - os.path.getmtime(sys.argv[1]))
except OSError:
    raise SystemExit(1)
raise SystemExit(0 if age <= int(sys.argv[2]) else 1)
PY
}

download_and_install() {
    local url

    TEMP_FILE=$(mktemp "$CACHE_DIR/.$YEAR.XXXXXX.json") || {
        printf '无法创建节假日缓存临时文件\n' >&2
        return 1
    }

    for url in "$PRIMARY_URL" "$FALLBACK_URL"; do
        if curl \
            --fail \
            --location \
            --silent \
            --show-error \
            --connect-timeout 3 \
            --max-time 10 \
            --retry 2 \
            --output "$TEMP_FILE" \
            "$url" \
            && validate_json "$TEMP_FILE"; then
            if mv -f -- "$TEMP_FILE" "$CACHE_FILE"; then
                TEMP_FILE=""
                cat -- "$CACHE_FILE"
                return 0
            fi
            printf '无法原子替换节假日缓存: %s\n' "$CACHE_FILE" >&2
            return 1
        fi
    done

    printf '无法下载或校验 %s 年节假日数据，保留现有缓存\n' "$YEAR" >&2
    return 1
}

mkdir -p -- "$CACHE_DIR" || {
    printf '无法创建节假日缓存目录: %s\n' "$CACHE_DIR" >&2
    exit 1
}

case "$MODE" in
    load)
        if [ -f "$CACHE_FILE" ] && validate_json "$CACHE_FILE"; then
            cat -- "$CACHE_FILE"
            exit 0
        fi
        download_and_install
        ;;
    refresh)
        if [ -f "$CACHE_FILE" ] \
            && validate_json "$CACHE_FILE" \
            && cache_is_fresh "$CACHE_FILE"; then
            exit 0
        fi
        download_and_install
        ;;
esac
