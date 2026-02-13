#!/bin/bash
CAVA_CONFIG=$(mktemp /tmp/cava-qs-XXXXXX.conf)
cat > "$CAVA_CONFIG" << 'CONFEOF'
[general]
bars = 8
sleep_timer = 0
[input]
method = pulse
source = auto
[output]
method = raw
data_format = ascii
ascii_max_range = 7
bar_delimiter = 59
frame_delimiter = 10
CONFEOF
trap "rm -f $CAVA_CONFIG" EXIT
CHARS="▁▂▃▄▅▆▇█"
cava -p "$CAVA_CONFIG" 2>/dev/null | while IFS= read -r line; do
    bars=""
    all_zero=true
    IFS=';' read -ra vals <<< "$line"
    for v in "${vals[@]}"; do
        [ -z "$v" ] && continue
        idx=$((v))
        [ "$idx" -lt 0 ] && idx=0
        [ "$idx" -gt 7 ] && idx=7
        bars="${bars}${CHARS:$idx:1}"
        [ "$idx" -gt 0 ] && all_zero=false
    done
    [ -z "$bars" ] && continue
    if $all_zero; then
        printf '{"active":false,"bars":"%s"}\n' "$bars"
    else
        printf '{"active":true,"bars":"%s"}\n' "$bars"
    fi
done
