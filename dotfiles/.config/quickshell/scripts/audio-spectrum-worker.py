#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""VCPChat rust_audio_engine 频谱算法的 Python 移植。

数据流（对齐 VCPChat player/spectrum.rs + processor/spectrum.rs）：
    stdin: f32le 单声道 PCM（由 pw-record --raw --format=f32 --rate=48000 --channels=1 提供）
    攒满 window(2048) 个采样 → Hann 加窗 → rfft → 跳过 DC
    → 20Hz..Nyquist 对数切 bins(64) 段 → 每段 RMS
    → 20*log10(rms + 1e-9) → ((db + 90) / 90) clamp(0,1)
    → stdout: 每帧一行 "v0 v1 ... v63"（0~1 浮点，VCPChat spectrum_data 同刻度）

关键参数与 VCPChat 完全一致：
    window = 2048（每 2048 样本一帧，48kHz 下 ≈23.4 帧/秒，非重叠——
            VCPChat 频谱线程攒满即清空缓冲）
    bins   = 64（对数分布）
    动态范围 = 90dB（-90dB → 0，0dB → 1）
"""

import argparse
import math
import sys

import numpy as np


def build_bin_edges(window: int, rate: float, bins: int, fmin: float) -> list:
    """把 20Hz..Nyquist 按 log10 线性切成 bins 段，映射到 FFT 下标区间。

    对齐 VCPChat SpectrumAnalyzer：freq_i = fmin * (fmax/fmin)^(i/bins)，
    fft_idx = floor(freq_i / rate * window)；每段保证至少 1 个 FFT bin。
    返回长度 bins+1 的递增下标序列 [e0..ebins)。
    """
    fmax = rate / 2.0
    freqs = [fmin * (fmax / fmin) ** (i / bins) for i in range(bins + 1)]
    edges = [max(1, int(freqs[i] / rate * window)) for i in range(bins + 1)]
    # 保证严格递增且每段宽度 >= 1（低频段多个 bin 会落在同一 FFT 格上）
    for i in range(1, bins + 1):
        if edges[i] <= edges[i - 1]:
            edges[i] = edges[i - 1] + 1
    return edges


def analyze(frame: np.ndarray, window: int, hann: np.ndarray,
            edges: list, bins: int) -> np.ndarray:
    """单帧分析：加窗 → rfft → 对数分箱 RMS → dB 归一化。

    逐条对齐 VCPChat processor/spectrum.rs：
      ① Hann 窗（0.5*(1-cos(2πi/N))，周期型）
      ② 幅度 = |rfft| / fft_size，跳过 DC（下标 1 起）
      ③ 对数分箱
      ④ RMS → 20*log10 → (db+90)/90 clamp
    """
    spec = np.abs(np.fft.rfft(frame * hann)) / window   # 幅度谱
    spec = spec[1:]                                     # 跳过 DC
    nyq = len(spec)                                     # 可用 bin 数 = window/2

    out = np.empty(bins, dtype=np.float64)
    for i in range(bins):
        lo = min(edges[i], nyq)
        hi = min(edges[i + 1], nyq)
        if hi <= lo:
            hi = min(lo + 1, nyq)
        seg = spec[lo - 1:hi - 1] if lo >= 1 else spec[0:max(hi - 1, 1)]
        if seg.size == 0:
            out[i] = 0.0
            continue
        rms = math.sqrt(float(np.mean(seg * seg)))
        db = 20.0 * math.log10(rms + 1e-9)
        out[i] = min(1.0, max(0.0, (db + 90.0) / 90.0))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="VCPChat-style spectrum worker")
    ap.add_argument("--window", type=int, default=2048)
    ap.add_argument("--bins", type=int, default=64)
    ap.add_argument("--rate", type=int, default=48000)
    ap.add_argument("--fmin", type=float, default=20.0)
    ap.add_argument("--precision", type=int, default=4,
                    help="每帧输出的小数位数")
    args = ap.parse_args()

    n = args.window
    if n <= 0 or args.bins <= 0 or args.rate <= 0:
        print("invalid arguments", file=sys.stderr)
        return 2

    # 周期型 Hann：0.5*(1-cos(2πi/N))，与 Rust 端公式一致
    hann = 0.5 - 0.5 * np.cos(2.0 * np.pi * np.arange(n) / n)
    edges = build_bin_edges(n, float(args.rate), args.bins, args.fmin)

    fmt = "%%.%df" % max(1, args.precision)
    buf = np.empty(n, dtype=np.float32)
    filled = 0
    out = sys.stdout

    while True:
        try:
            chunk = sys.stdin.buffer.read(65536)
        except (KeyboardInterrupt, BrokenPipeError):
            break
        if not chunk:
            break
        data = np.frombuffer(chunk, dtype=np.float32)
        offset = 0
        while offset < len(data):
            take = min(n - filled, len(data) - offset)
            buf[filled:filled + take] = data[offset:offset + take]
            filled += take
            offset += take
            if filled == n:
                vals = analyze(buf, n, hann, edges, args.bins)
                try:
                    out.write(" ".join(fmt % v for v in vals) + "\n")
                    out.flush()
                except BrokenPipeError:
                    return 0
                filled = 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
