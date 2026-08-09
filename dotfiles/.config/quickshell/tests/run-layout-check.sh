#!/usr/bin/env bash
set -u

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target="${script_dir}/edge-integrated-layout-check.qml"
timeout_seconds="${LAYOUT_CHECK_TIMEOUT:-8}"
log_file="$(mktemp "${TMPDIR:-/tmp}/edge-integrated-layout-check.XXXXXX.log")"
runtime_dir="$(mktemp -d "${TMPDIR:-/tmp}/edge-integrated-runtime.XXXXXX")"
child_pid=""

chmod 700 "${runtime_dir}"

cleanup() {
    if [[ -n "${child_pid}" ]] && kill -0 "${child_pid}" 2>/dev/null; then
        kill "${child_pid}" 2>/dev/null || true
        wait "${child_pid}" 2>/dev/null || true
    fi
    rm -f "${log_file}"
    if [[ -d "${runtime_dir}" ]]; then
        find "${runtime_dir}" -mindepth 1 -delete 2>/dev/null || true
        rmdir "${runtime_dir}" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

XDG_RUNTIME_DIR="${runtime_dir}" quickshell -p "${target}" >"${log_file}" 2>&1 &
child_pid=$!
deadline=$((SECONDS + timeout_seconds))

while kill -0 "${child_pid}" 2>/dev/null; do
    if grep -q '\[EdgeIntegratedLayoutCheck\] PASS' "${log_file}"; then
        cat "${log_file}"
        kill "${child_pid}" 2>/dev/null || true
        wait "${child_pid}" 2>/dev/null || true
        exit 0
    fi
    if grep -q '\[EdgeIntegratedLayoutCheck\] FAIL' "${log_file}"; then
        cat "${log_file}"
        exit 1
    fi
    if (( SECONDS >= deadline )); then
        echo "[EdgeIntegratedLayoutCheck] TIMEOUT after ${timeout_seconds}s" >&2
        cat "${log_file}" >&2
        exit 2
    fi
    sleep 0.05
done

wait "${child_pid}" 2>/dev/null || child_status=$?
child_status="${child_status:-0}"
cat "${log_file}"
if grep -q '\[EdgeIntegratedLayoutCheck\] PASS' "${log_file}"; then
    exit 0
fi
exit "${child_status}"
