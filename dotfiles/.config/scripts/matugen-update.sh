#!/bin/bash
# --- 参数定义 ---
WALLPAPER="$1"
CACHE_DIR="$HOME/.cache/matugen-strategy"
TYPE_FILE="$CACHE_DIR/type"
MODE_FILE="$CACHE_DIR/mode"
WAYPAPER_CONFIG="$HOME/.config/waypaper/config.ini"
# --- 1. 获取壁纸路径 ---
if [ -z "$WALLPAPER" ]; then
    WALLPAPER=$(grep "^wallpaper =" "$WAYPAPER_CONFIG" | cut -d " " -f 3)
fi
if [ ! -f "$WALLPAPER" ]; then
    exit 1
fi
# --- 2. 获取策略和模式 ---
mkdir -p "$CACHE_DIR"
[ ! -f "$TYPE_FILE" ] && echo "scheme-tonal-spot" > "$TYPE_FILE"
[ ! -f "$MODE_FILE" ] && echo "dark" > "$MODE_FILE"
STRATEGY=$(cat "$TYPE_FILE")
MODE=$(cat "$MODE_FILE")
# --- 3. 执行 Matugen (非TTY环境修复: 使用 --prefer 避免交互) ---
matugen image "$WALLPAPER" -t "$STRATEGY" -m "$MODE" --prefer=saturation