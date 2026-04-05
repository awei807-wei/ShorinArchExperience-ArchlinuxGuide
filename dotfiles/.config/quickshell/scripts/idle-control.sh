#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
FLAG_FILE="$STATE_DIR/idle_enabled"
PID_FILE="$STATE_DIR/swayidle.pid"
LOCKER_CMD="$HOME/.config/quickshell/scripts/lockscreen.sh"

LOCK_TIMEOUT=1800
SCREEN_OFF_TIMEOUT=2400
SUSPEND_TIMEOUT=3600

mkdir -p "$STATE_DIR"

normalize_flag() {
    local value="${1:-}"
    value="${value,,}"
    case "$value" in
        1|true|on|enable|enabled|yes)
            printf 'true\n'
            ;;
        0|false|off|disable|disabled|no)
            printf 'false\n'
            ;;
        *)
            printf 'true\n'
            ;;
    esac
}

ensure_flag() {
    if [[ ! -f "$FLAG_FILE" ]]; then
        printf 'true\n' > "$FLAG_FILE"
        return
    fi

    local current
    current="$(tr -d '[:space:]' < "$FLAG_FILE")"
    printf '%s\n' "$(normalize_flag "$current")" > "$FLAG_FILE"
}

read_flag() {
    ensure_flag
    normalize_flag "$(tr -d '[:space:]' < "$FLAG_FILE")"
}

write_flag() {
    printf '%s\n' "$(normalize_flag "${1:-true}")" > "$FLAG_FILE"
}

stop_managed_idle() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
        fi
        rm -f "$PID_FILE"
    fi

    pkill -x swayidle 2>/dev/null || true
}

start_idle() {
    stop_managed_idle

    if [[ "$(read_flag)" != "true" ]]; then
        return
    fi

    swayidle \
        timeout "$LOCK_TIMEOUT" "$LOCKER_CMD" \
        timeout "$SCREEN_OFF_TIMEOUT" "niri msg action power-off-monitors" \
            resume "niri msg action power-on-monitors" \
        timeout "$SUSPEND_TIMEOUT" "systemctl suspend" \
        before-sleep "$LOCKER_CMD" \
        lock "$LOCKER_CMD" &

    local pid="$!"
    printf '%s\n' "$pid" > "$PID_FILE"
    disown "$pid" 2>/dev/null || true
}

print_usage() {
    cat <<'EOF'
Usage: idle-control.sh [ensure|status|is-enabled|enable|disable|toggle|start|restart|stop]
EOF
}

case "${1:-status}" in
    ensure)
        ensure_flag
        ;;
    status)
        read_flag
        ;;
    is-enabled)
        if [[ "$(read_flag)" == "true" ]]; then
            printf '1\n'
        else
            printf '0\n'
        fi
        ;;
    enable)
        write_flag true
        start_idle
        read_flag
        ;;
    disable)
        write_flag false
        stop_managed_idle
        read_flag
        ;;
    toggle)
        if [[ "$(read_flag)" == "true" ]]; then
            write_flag false
            stop_managed_idle
        else
            write_flag true
            start_idle
        fi
        read_flag
        ;;
    start|restart)
        start_idle
        ;;
    stop)
        stop_managed_idle
        ;;
    *)
        print_usage >&2
        exit 1
        ;;
esac
