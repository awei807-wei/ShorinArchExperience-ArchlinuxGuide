#!/bin/sh
# run-spectrum.sh — 频谱采集启动器（CavaService 的 Process 入口）。
#
# 用法: run-spectrum.sh <node.name> <worker.py> [rate]
#
# pw-record 的 --target 只认 object.serial（node.name/".monitor"/node id 均
# 报 "no target node available"，实测 PipeWire 1.6.8），因此启动时用
# pw-dump 把 node.name 解析成 serial，再拉起采集管线：
#   pw-record(f32le/48k/mono) | audio-spectrum-worker.py(Hann+FFT→对数64bin→RMS→dB)
# stdout 为每帧一行 0~1 浮点（VCPChat spectrum_data 同刻度）。

set -eu

NAME="${1:?node.name required}"
WORKER="${2:?worker path required}"
RATE="${3:-48000}"

SERIAL=$(pw-dump 2>/dev/null | python3 -c '
import json
import sys

name = sys.argv[1]
try:
    objs = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for o in objs:
    props = (o.get("info") or {}).get("props") or {}
    if props.get("node.name") == name:
        print(props.get("object.serial", ""))
        break
' "$NAME")

if [ -z "$SERIAL" ]; then
    echo "run-spectrum: no pipewire node named '$NAME'" >&2
    exit 1
fi

exec pw-record --raw --format=f32 --rate="$RATE" --channels=1 --target "$SERIAL" - \
    | exec python3 "$WORKER"
