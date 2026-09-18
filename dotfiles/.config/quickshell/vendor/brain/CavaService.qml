pragma Singleton

// Brain_Shell CavaService — 真实频谱版（VCPChat rust_audio_engine 算法移植）。
//
// 数据链路：
//   pw-record（默认 sink monitor，f32le/48k/单声道下混，PipeWire 自动 remix）
//     → scripts/audio-spectrum-worker.py（Hann + rfft → 对数 64 bin → RMS
//       → 20*log10 → (db+90)/90 归一化，参数逐条对齐 VCPChat）
//     → 每帧一行 ASCII "v0..v63"（0~1）→ SplitParser → targetSpectrum
//   → 16ms Timer 指数缓动 easingFactor=0.18（对齐 VCPChat 前端
//     music.js 的 rAF 追踪层，把 ~23Hz 的台阶抹成平滑动画）
//   → bars（32 × 0..100 整数，Brain_Shell PlayerCard 既有契约不变）
//
// active 门控（CenterDashboard 注入：面板展开 + Home 页 + 非减少动画）
// 启停整条链路；默认 sink 变更时自动重启采集；异常退出按退避重启。
// 替换自 Brain_Shell (MIT) 的 mock shim。
import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire

QtObject {
    id: root

    readonly property int barCount: 32        // 兼容契约：PlayerCard 32 根
    readonly property int binCount: 64        // VCPChat 对数 bin 数

    // 装饰动画活动开关：由消费方汇总驱动，不由 Item 可见性隐式推断
    property bool active: false

    // VCPChat 归一化频谱目标帧（0..1 × 64）
    property var targetSpectrum: []
    // 缓动后的频谱（0..1 × 64），未来沉浸式渲染可直接消费
    property var easedSpectrum: []
    // 兼容 Brain_Shell PlayerCard 的 bars 契约（32 × 0..100 整数）
    property var bars: []

    // ── VCPChat 参数（worker 侧同步使用） ─────────────────────────────────────
    readonly property real easingFactor: 0.18   // music.js:167
    readonly property int windowSize: 2048
    readonly property int sampleRate: 48000

    // ── 采集源：默认 sink（capture 指向 sink 即取其 monitor 端口） ────────────
    // 注意：node 在 bind 前可能短暂拿到无效 name（PwNode.ready 长期不翻转，
    // 不能用它做门控）→ 空目标由 Process 命令行守卫 + 退避重启兜底
    readonly property string sinkName:
        Pipewire.ready && Pipewire.defaultAudioSink
            ? (Pipewire.defaultAudioSink.name ?? "") : ""

    // worker / launcher 脚本绝对路径（本文件在 vendor/brain/ 下，上两级是配置根）
    readonly property string _workerPath: {
        var u = Qt.resolvedUrl("../../scripts/audio-spectrum-worker.py").toString()
        return u.replace(/^file:\/\//, "")
    }
    readonly property string _launcherPath: {
        var u = Qt.resolvedUrl("../../scripts/run-spectrum.sh").toString()
        return u.replace(/^file:\/\//, "")
    }

    property real _restartDelayMs: 300
    property real _lastStartAt: 0

    // QtObject 无默认子属性：采集进程挂为 property（下同 Timer）。
    // pw-record --target 只认 object.serial → launcher 启动时用 pw-dump 解析
    property Process spectrumProc: Process {
        id: spectrumProc
        command: [
            "sh", "-c",
            "[ -n \"$QS_SINK_TARGET\" ] || { echo \"[CavaService] sink target not ready, skip spawn\" >&2; exit 0; } ; "
                + "exec \"$QS_SPECTRUM_LAUNCHER\" \"$QS_SINK_TARGET\" \"$QS_SPECTRUM_WORKER\" "
                + root.sampleRate
        ]
        environment: ({
            QS_SINK_TARGET: root.sinkName,
            QS_SPECTRUM_WORKER: root._workerPath,
            QS_SPECTRUM_LAUNCHER: root._launcherPath
        })
        stdout: SplitParser {
            onRead: data => root._acceptFrame(data)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim() !== "")
                    console.warn("[CavaService] pw-record/worker stderr:", text.trim())
            }
        }
        onStarted: root._lastStartAt = Date.now()
        onExited: root._onExited()
    }

    // 异常退出退避重启（目标 sink 消失/损坏时避免疯狂拉起）
    property Timer _restartTimer: Timer {
        interval: root._restartDelayMs
        repeat: false
        onTriggered: root._syncRunning()
    }

    // 16ms ≈ 60fps：0.18 指数缓动追踪（VCPChat 前端层）
    property Timer _easeTimer: Timer {
        interval: 16
        repeat: true
        running: root.active
        onTriggered: root._easeStep()
    }

    Component.onCompleted: {
        root._fillZeros()
        root._syncRunning()
    }
    onActiveChanged: root._syncRunning()
    // 默认 sink 变化/就绪：running 中则重启采集（command/environment 属
    // "下次启动生效"）；未运行（含初始 Pipewire 就绪晚于 active 置位的竞态）
    // 则直接尝试启动
    onSinkNameChanged: {
        if (!root.active)
            return
        if (spectrumProc.running) {
            spectrumProc.running = false
            root._restartTimer.restart()
        } else {
            root._syncRunning()
        }
    }

    function _syncRunning() {
        const want = root.active && root.sinkName !== ""
        if (want && !spectrumProc.running) {
            spectrumProc.running = true
        } else if (!want && spectrumProc.running) {
            spectrumProc.running = false
        }
        if (!root.active) {
            root._restartDelayMs = 300
        }
    }

    function _onExited() {
        const ran = Date.now() - root._lastStartAt
        // 短命进程 → 指数退避（上限 5s）；稳定运行过 → 恢复快速重启
        root._restartDelayMs = ran < 1000
            ? Math.min(5000, Math.max(300, root._restartDelayMs * 2))
            : 300
        if (root.active && root.sinkName !== "")
            root._restartTimer.restart()
    }

    // 一帧 "v0 v1 ... v63"（0~1）→ targetSpectrum
    function _acceptFrame(data) {
        const parts = data.trim().split(" ")
        if (parts.length !== root.binCount)
            return
        const frame = new Array(root.binCount)
        for (let i = 0; i < root.binCount; ++i) {
            const v = Number(parts[i])
            if (Number.isNaN(v))
                return
            frame[i] = Math.min(1, Math.max(0, v))
        }
        root.targetSpectrum = frame
    }

    // 每步：eased += (target - eased) * 0.18；bars = 相邻两 bin 均值 × 100
    function _easeStep() {
        const target = root.targetSpectrum
        const eased = root.easedSpectrum
        const bars = new Array(root.barCount)
        for (let i = 0; i < root.binCount; ++i) {
            eased[i] += (target[i] - eased[i]) * root.easingFactor
            // 贴地噪声抑制（与 VCPChat 观感一致：绝对静音时归零）
            if (eased[i] < 0.005)
                eased[i] = 0
        }
        for (let j = 0; j < root.barCount; ++j) {
            const avg = (eased[j * 2] + eased[j * 2 + 1]) / 2
            bars[j] = Math.max(0, Math.min(100, Math.round(avg * 100)))
        }
        root.easedSpectrum = eased
        root.bars = bars
    }

    function _fillZeros() {
        root.targetSpectrum = new Array(root.binCount).fill(0)
        root.easedSpectrum = new Array(root.binCount).fill(0)
        root.bars = new Array(root.barCount).fill(0)
    }
}
