#!/bin/bash
# === CAVA 频谱可视化 for Waybar ===
# 核心修复：class 只在状态切换时改变，让 transition 生效

bar="▁▂▃▄▅▆▇█"
config_file="/tmp/waybar_cava_config"
state_file="/tmp/waybar_cava_state"
silent_pattern="▁▁▁▁▁▁▁▁▁▁"

DEBOUNCE_SECONDS=3
FADEOUT_SECONDS=1

trap "rm -f $state_file; pkill -P $$" EXIT

# 状态: current_state|silence_start|last_class
# current_state: hidden / visible / fadeout
echo "hidden|0|" > "$state_file"

# 生成 cava 配置
cat > "$config_file" << 'EOF'
[general]
framerate = 24
bars = 10

[input]
method = pulse

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
EOF

# 构建 sed 替换
dict="s/;//g;"
for i in $(seq 0 7); do
    dict="${dict}s/$i/${bar:$i:1}/g;"
done

# 主循环
cava -p "$config_file" 2>/dev/null | sed -u "$dict" | while IFS= read -r line; do
    now=$(date +%s)
    
    # 读取状态
    IFS='|' read -r state silence_start last_class < "$state_file"
    
    if [[ "$line" != "$silent_pattern" ]]; then
        # === 有声音 ===
        if [[ "$state" != "visible" ]]; then
            # 状态切换：hidden/fadeout → visible
            echo "visible|0|visible" > "$state_file"
            printf '{"text": "%s", "class": "visible"}\n' "$line"
        else
            # 保持 visible，不改变 class（关键！让 transition 稳定）
            printf '{"text": "%s", "class": "visible"}\n' "$line"
        fi
    else
        # === 静音 ===
        if [[ "$state" == "hidden" ]]; then
            echo '{"text": ""}'
            continue
        fi
        
        # 记录静音开始时间
        if [[ "$silence_start" == "0" ]]; then
            echo "$state|$now|$last_class" > "$state_file"
            silence_start=$now
        fi
        
        elapsed=$((now - silence_start))
        
        if [[ $elapsed -lt $DEBOUNCE_SECONDS ]]; then
            # 防抖期间保持 visible
            printf '{"text": "%s", "class": "visible"}\n' "$line"
        elif [[ $elapsed -lt $((DEBOUNCE_SECONDS + FADEOUT_SECONDS)) ]]; then
            # 淡出阶段
            if [[ "$state" != "fadeout" ]]; then
                # 状态切换：visible → fadeout（只切换一次！）
                echo "fadeout|$silence_start|fadeout" > "$state_file"
            fi
            printf '{"text": "%s", "class": "fadeout"}\n' "$line"
        else
            # 隐藏
            echo "hidden|0|" > "$state_file"
            echo '{"text": ""}'
        fi
    fi
done