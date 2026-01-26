#!/usr/bin/env bash
# AGS Cava 频谱脚本 - 常驻显示版

CONFIG_FILE="/tmp/ags_cava_config"

cat > "$CONFIG_FILE" << EOF
[general]
bars = 8
framerate = 30
[input]
method = pipewire
source = auto
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
EOF

bar_chars="▁▂▃▄▅▆▇█"
low_bars="▁▁▁▁▁▁▁▁"

/usr/bin/cava -p "$CONFIG_FILE" 2>/dev/null | while IFS= read -r line; do
    nums=$(echo "$line" | tr -cd '0-7')
    bars=""
    for ((i=0; i<${#nums}; i++)); do
        n="${nums:$i:1}"
        bars+="${bar_chars:$n:1}"
    done
    
    if [[ -n "$bars" ]]; then
        echo "$bars"
    else
        echo "$low_bars"
    fi
done