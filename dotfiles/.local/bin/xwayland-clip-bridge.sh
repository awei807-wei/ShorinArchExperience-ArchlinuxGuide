#!/bin/bash
# X11 <-> Wayland 双向剪贴板同步桥
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

last_x11=""
last_wayland=""

# 后台监听 Wayland -> X11
wl-paste --watch bash -c '
    w_clip=$(wl-paste 2>/dev/null)
    x_clip=$(DISPLAY=:0 xclip -selection clipboard -o 2>/dev/null)
    if [[ -n "$w_clip" && "$w_clip" != "$x_clip" ]]; then
        echo -n "$w_clip" | DISPLAY=:0 xclip -selection clipboard 2>/dev/null
    fi
' &
WL_PID=$!

trap "kill $WL_PID 2>/dev/null; exit 0" SIGINT SIGTERM EXIT

# 主循环监听 X11 -> Wayland
while true; do
    x_clip=$(DISPLAY=:0 xclip -selection clipboard -o 2>/dev/null)
    if [[ -n "$x_clip" && "$x_clip" != "$last_x11" ]]; then
        w_clip=$(wl-paste 2>/dev/null)
        if [[ "$x_clip" != "$w_clip" ]]; then
            echo -n "$x_clip" | wl-copy 2>/dev/null
            last_wayland="$x_clip"
        fi
        last_x11="$x_clip"
    fi
    sleep 0.5
done
