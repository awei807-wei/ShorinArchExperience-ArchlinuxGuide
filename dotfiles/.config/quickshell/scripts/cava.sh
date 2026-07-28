#!/bin/bash
# 模块：cava.sh（Quickshell 频谱桥接脚本）
# 功能：启动 cava 并把其 raw/ascii 输出转换成 Quickshell 友好的 JSON 行流：
# - bars: 由 32 个“高度字符”组成的频谱字符串（用于 SystemIsland 背景暗纹）
# - active: 是否存在非零柱（用于 UI 判定“当前是否有声音输入/播放”）
# 注意：
# - 本脚本是“长驻输出”模式：被 Quickshell.Io.Process 常驻启动并持续读取 stdout
# - 输出必须是一行一个 JSON（便于 SplitParser 逐行解析）

CAVA_CONFIG=$(mktemp /tmp/cava-qs-XXXXXX.conf) # 临时 cava 配置文件路径（退出时清理）
cat > "$CAVA_CONFIG" << 'CONFEOF'
[general]
bars = 32
framerate = 12
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
trap 'rm -f "$CAVA_CONFIG"' EXIT # 退出时删除临时配置文件（避免 /tmp 堆积）

CHARS="▁▂▃▄▅▆▇█" # 高度字符表：索引 0~7 映射到从低到高的柱形符号

# 启动 cava 并逐帧读取其输出。每帧由 ';' 分隔的 0~7 数字组成（对应 8 个 bars）。
cava -p "$CAVA_CONFIG" 2>/dev/null | while IFS= read -r line; do
    bars="" # 组装后的字符柱字符串（长度=bars 数）
    all_zero=true # 是否整帧全为 0（用于计算 active 字段）

    IFS=';' read -ra vals <<< "$line" # 把一帧拆成数值数组（每个元素为一个 bar 的高度）
    for v in "${vals[@]}"; do
        [ -z "$v" ] && continue
        idx=$((v)) # 当前 bar 的高度索引（期望 0~7；做一次夹紧防御）
        [ "$idx" -lt 0 ] && idx=0 # 下限夹紧：避免异常值导致 substring 越界
        [ "$idx" -gt 7 ] && idx=7 # 上限夹紧：配合 ascii_max_range=7
        bars="${bars}${CHARS:$idx:1}" # 追加当前 bar 的高度字符
        [ "$idx" -gt 0 ] && all_zero=false # 任意一列非 0 即认为 active=true
    done
    [ -z "$bars" ] && continue # 空帧直接跳过（避免输出无意义 JSON）
    if $all_zero; then
        printf '{"active":false,"bars":"%s"}\n' "$bars" # 静默帧：没有声音输入
    else
        printf '{"active":true,"bars":"%s"}\n' "$bars" # 活跃帧：至少一列非零
    fi
done
