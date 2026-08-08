#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helper="$script_dir/focus-tray-item.sh"
windows_json='[
  {"id": 11, "app_id": "org.example.Lark", "title": "飞书", "focus_timestamp": {"secs": 10, "nanos": 0}},
  {"id": 12, "app_id": "org.example.Lark", "title": "飞书会议", "focus_timestamp": {"secs": 30, "nanos": 0}},
  {"id": 13, "app_id": "org.example.Other", "title": "飞书", "focus_timestamp": {"secs": 99, "nanos": 0}},
  {"id": 14, "app_id": "org.example.Chrome", "title": "VCP AI 聊天客户端", "focus_timestamp": {"secs": 40, "nanos": 0}}
]'

selected="$({
    FOCUS_TRAY_WINDOWS_JSON="$windows_json" \
        FOCUS_TRAY_DRY_RUN=1 \
        bash "$helper" "lark_status_icon_1" "Lark" "飞书"
})"
[[ "$selected" == "12" ]]

selected="$({
    FOCUS_TRAY_WINDOWS_JSON="$windows_json" \
        FOCUS_TRAY_DRY_RUN=1 \
        bash "$helper" "chrome_status_icon_1" "Chrome" "VCP AI 聊天客户端"
})"
[[ "$selected" == "14" ]]

selected="$({
    FOCUS_TRAY_WINDOWS_JSON="$windows_json" \
        FOCUS_TRAY_DRY_RUN=1 \
        bash "$helper" "missing_status_icon" "QQ" "QQ"
})"
[[ -z "$selected" ]]

printf '%s\n' "[FocusTrayCheck] PASS"
