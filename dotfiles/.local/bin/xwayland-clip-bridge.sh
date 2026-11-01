#!/bin/bash
# X11 <-> Wayland 双向剪贴板同步桥 (带超时防护与防死锁)
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

HASH_FILE="/dev/shm/xwayland_clip_bridge_${UID}.hash"
echo "" > "$HASH_FILE"

get_last_hash() {
    cat "$HASH_FILE" 2>/dev/null
}

set_last_hash() {
    echo "$1" > "$HASH_FILE"
}

# 监听 Wayland -> X11
wl-paste --watch bash -c '
    HASH_FILE="/dev/shm/xwayland_clip_bridge_'${UID}'.hash"
    export DISPLAY="${DISPLAY:-:0}"
    export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

    types=$(timeout 0.8s wl-paste --list-types 2>/dev/null)
    [ -z "$types" ] && exit 0

    last_hash=$(cat "$HASH_FILE" 2>/dev/null)

    if echo "$types" | grep -q "^image/png"; then
        cur_hash=$(timeout 1.5s wl-paste --type image/png --no-newline 2>/dev/null | md5sum | cut -d" " -f1)
        if [[ -n "$cur_hash" && "$cur_hash" != "$last_hash" ]]; then
            echo "$cur_hash" > "$HASH_FILE"
            timeout 1.5s wl-paste --type image/png --no-newline 2>/dev/null | timeout 1.5s xclip -selection clipboard -t image/png 2>/dev/null
        fi
    elif echo "$types" | grep -Eq "text/plain|UTF8_STRING|STRING"; then
        cur_hash=$(timeout 0.8s wl-paste --no-newline 2>/dev/null | md5sum | cut -d" " -f1)
        if [[ -n "$cur_hash" && "$cur_hash" != "$last_hash" ]]; then
            echo "$cur_hash" > "$HASH_FILE"
            timeout 0.8s wl-paste --no-newline 2>/dev/null | timeout 0.8s xclip -selection clipboard 2>/dev/null
        fi
    fi
' &
WL_PID=$!

trap "kill $WL_PID 2>/dev/null; rm -f $HASH_FILE; exit 0" SIGINT SIGTERM EXIT

# 轮询监听 X11 -> Wayland
while true; do
    x_targets=$(timeout 0.8s xclip -selection clipboard -t TARGETS -o 2>/dev/null)
    last_hash=$(get_last_hash)

    if echo "$x_targets" | grep -q "^image/png"; then
        cur_hash=$(timeout 1.5s xclip -selection clipboard -t image/png -o 2>/dev/null | md5sum | cut -d" " -f1)
        if [[ -n "$cur_hash" && "$cur_hash" != "$last_hash" ]]; then
            set_last_hash "$cur_hash"
            timeout 1.5s xclip -selection clipboard -t image/png -o 2>/dev/null | timeout 1.5s wl-copy --type image/png 2>/dev/null
        fi
    elif echo "$x_targets" | grep -Eq "UTF8_STRING|STRING|TEXT"; then
        cur_hash=$(timeout 0.8s xclip -selection clipboard -o 2>/dev/null | md5sum | cut -d" " -f1)
        if [[ -n "$cur_hash" && "$cur_hash" != "$last_hash" ]]; then
            set_last_hash "$cur_hash"
            timeout 0.8s xclip -selection clipboard -o 2>/dev/null | timeout 0.8s wl-copy 2>/dev/null
        fi
    fi
    sleep 0.6
done
