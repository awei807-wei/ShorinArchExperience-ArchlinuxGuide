// Brain_Shell CpuService — 真实数据。/proc/stat 差分计算 CPU 占用。
import QtQuick
import Quickshell.Io

QtObject {
    id: svc

    property bool active: false
    property real usagePercent: 0
    property var _prev: null

    property Process cpuProc: Process {
        stdout: SplitParser {
            onRead: line => {
                const parts = line.trim().split(/\s+/).slice(1).map(Number)
                if (parts.length < 5)
                    return
                const total = parts.reduce((a, b) => a + b, 0)
                const idle = parts[3] + parts[4]
                const prev = svc._prev
                if (prev && total > prev.total) {
                    const used = 1 - (idle - prev.idle) / (total - prev.total)
                    svc.usagePercent = Math.max(0, Math.min(100,
                        Math.round(used * 1000) / 10))
                }
                svc._prev = { "total": total, "idle": idle }
            }
        }
    }

    property Timer pollTimer: Timer {
        interval: 1000
        repeat: true
        running: svc.active
        onTriggered: {
            cpuProc.command = ["sh", "-c", "grep '^cpu ' /proc/stat"]
            cpuProc.running = false
            cpuProc.running = true
        }
    }
}
