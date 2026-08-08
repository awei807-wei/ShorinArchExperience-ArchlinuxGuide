#!/usr/bin/env bash
set -euo pipefail

tray_id="${1:-}"
tray_title="${2:-}"
tray_tooltip="${3:-}"

normalize() {
    printf '%s' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/\.desktop$//; s/[^[:alnum:]]+//g'
}

tray_id_norm="$(normalize "$tray_id")"
tray_title_norm="$(normalize "$tray_title")"
tray_tooltip_norm="$(normalize "$tray_tooltip")"

windows_json="${FOCUS_TRAY_WINDOWS_JSON:-}"
if [[ -z "$windows_json" ]]; then
    windows_json="$(niri msg -j windows 2>/dev/null || true)"
fi
if [[ -z "$windows_json" || "$windows_json" == "[]" ]]; then
    exit 0
fi

window_id="$(
    jq -r \
        --arg id "$tray_id_norm" \
        --arg title "$tray_title_norm" \
        --arg tooltip "$tray_tooltip_norm" '
        def norm:
            ascii_downcase
            | sub("\\.desktop$"; "")
            | gsub("[^[:alnum:]]+"; "");

        def score($id; $title; $tooltip):
            (.app_id // "" | norm) as $app_id
            | (.title // "" | norm) as $window_title
            | ($id | sub("statusicon[0-9]*$"; "")) as $id_base
            | if $id != "" and $app_id == $id then 100
              elif $id_base != "" and ($id_base | length) >= 3
                    and ($app_id | endswith($id_base)) then 95
              elif $title != "" and $app_id == $title then 90
              elif $tooltip != "" and $app_id == $tooltip then 80
              elif $title != "" and $window_title == $title then 70
              elif $tooltip != "" and $window_title == $tooltip then 60
              else 0 end;

        map(. + { _score: score($id; $title; $tooltip) })
        | map(select(._score > 0))
        | sort_by(._score, (.focus_timestamp.secs // 0), (.focus_timestamp.nanos // 0))
        | reverse
        | .[0].id // empty
        ' <<< "$windows_json"
 )"

if [[ -n "${FOCUS_TRAY_DRY_RUN:-}" ]]; then
    printf '%s\n' "$window_id"
elif [[ "$window_id" =~ ^[0-9]+$ ]]; then
    niri msg action focus-window --id "$window_id" >/dev/null 2>&1 || true
fi
