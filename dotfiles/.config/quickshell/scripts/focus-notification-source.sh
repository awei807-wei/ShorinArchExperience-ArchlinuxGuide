#!/usr/bin/env bash
set -euo pipefail

desktop_entry="${1:-}"
app_name="${2:-}"
summary="${3:-}"

normalize() {
    printf '%s' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/\.desktop$//; s/[^a-z0-9]+//g'
}

desktop_norm="$(normalize "$desktop_entry")"
app_norm="$(normalize "$app_name")"
summary_norm="$(normalize "$summary")"

windows_json="$(niri msg -j windows 2>/dev/null || true)"
if [[ -z "$windows_json" || "$windows_json" == "[]" ]]; then
    exit 0
fi

window_id="$(
    jq -r \
        --arg desktop "$desktop_norm" \
        --arg app "$app_norm" \
        --arg summary "$summary_norm" '
        def norm:
            ascii_downcase
            | sub("\\.desktop$"; "")
            | gsub("[^a-z0-9]+"; "");

        def score($desktop; $app; $summary):
            (.app_id // "" | norm) as $app_id
            | (.title // "" | norm) as $title
            | if $desktop != "" and $app_id == $desktop then 100
              elif $app != "" and $app_id == $app then 90
              elif $desktop != "" and $app_id != "" and (($app_id | contains($desktop)) or ($desktop | contains($app_id))) then 70
              elif $app != "" and $app_id != "" and (($app_id | contains($app)) or ($app | contains($app_id))) then 60
              elif $app != "" and $title != "" and ($title | contains($app)) then 30
              elif $summary != "" and $title != "" and ($title | contains($summary)) then 10
              else 0 end;

        map(. + { _score: score($desktop; $app; $summary) })
        | map(select(._score > 0))
        | sort_by(._score, (.focus_timestamp.secs // 0), (.focus_timestamp.nanos // 0))
        | reverse
        | .[0].id // empty
        ' <<< "$windows_json"
)"

if [[ "$window_id" =~ ^[0-9]+$ ]]; then
    niri msg action focus-window --id "$window_id" >/dev/null 2>&1 || true
fi
