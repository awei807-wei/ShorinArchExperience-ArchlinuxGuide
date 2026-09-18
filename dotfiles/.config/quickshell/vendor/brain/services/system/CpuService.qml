// Brain_Shell CpuService — 真实数据。/proc/stat 差分计算 CPU 占用。
import QtQuick
import Quickshell.Io
// PollTimer 经 ../qmldir 暴露：qs: 方案下同目录类型不会被自动发现
import "../"

QtObject {
    id: svc

    property bool active: false
    property real usagePercent: 0
    property var _prev: null

    // 上一样本超过这个间隔就只当作基准、不做差分：收起面板很久后再展开，
    // 差分出来的是整段空窗的平均值，不如保留上次读数等热身样本刷新
    readonly property int maxSampleGapMs: 5000

    property Process cpuProc: Process {
        stdout: SplitParser {
            onRead: line => {
                const parts = line.trim().split(/\s+/).slice(1).map(Number)
                if (parts.length < 5)
                    return
                const total = parts.reduce((a, b) => a + b, 0)
                const idle = parts[3] + parts[4]
                const now = Date.now()
                const prev = svc._prev
                if (prev && total > prev.total
                        && now - prev.t <= svc.maxSampleGapMs) {
                    const used = 1 - (idle - prev.idle) / (total - prev.total)
                    svc.usagePercent = Math.max(0, Math.min(100,
                        Math.round(used * 1000) / 10))
                }
                svc._prev = { "total": total, "idle": idle, "t": now }
            }
        }
    }

    // 激活即采样，300ms 后补第二个样本得到首个占用率，再回到 1s 周期
    property Timer pollTimer: PollTimer {
        active: svc.active
        period: 1000
        warmupPeriod: 300
        onTriggered: {
            cpuProc.command = ["sh", "-c", "grep '^cpu ' /proc/stat"]
            cpuProc.running = false
            cpuProc.running = true
        }
    }
}
