// Brain_Shell NetService — 真实数据。/proc/net/dev 差分计算上下行速率。
import QtQuick
import Quickshell.Io
// PollTimer 经 ../qmldir 暴露：qs: 方案下同目录类型不会被自动发现
import "../"

QtObject {
    id: svc

    property bool active: false
    property string iface: ""
    property string upSpeed: "0 B/s"
    property string downSpeed: "0 B/s"
    property var _prev: null

    // 上一样本超过这个间隔就只当作基准、不做差分（同 CpuService）
    readonly property int maxSampleGapMs: 5000

    function _fmt(bytesPerSec) {
        if (bytesPerSec >= 1048576)
            return (bytesPerSec / 1048576).toFixed(1) + " MB/s"
        if (bytesPerSec >= 1024)
            return Math.round(bytesPerSec / 1024) + " KB/s"
        return Math.round(bytesPerSec) + " B/s"
    }

    property Process netProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                let rxTotal = 0
                let txTotal = 0
                let primary = ""
                for (const line of this.text.split("\n")) {
                    const colon = line.indexOf(":")
                    if (colon < 0)
                        continue
                    const name = line.slice(0, colon).trim()
                    if (name === "lo")
                        continue
                    const fields = line.slice(colon + 1).trim().split(/\s+/)
                    if (fields.length < 9)
                        continue
                    const rx = Number(fields[0])
                    const tx = Number(fields[8])
                    if (!isFinite(rx) || !isFinite(tx))
                        continue
                    rxTotal += rx
                    txTotal += tx
                    if (primary === "")
                        primary = name
                }
                if (primary === "")
                    return
                svc.iface = primary
                // 速率按两次采样的真实时间差计算：热身样本只隔 300ms，
                // 常规样本也有进程启动抖动，不能再假定固定 2s
                const now = Date.now()
                const prev = svc._prev
                if (prev && rxTotal >= prev.rx && txTotal >= prev.tx) {
                    const dt = (now - prev.t) / 1000
                    if (dt > 0.05 && now - prev.t <= svc.maxSampleGapMs) {
                        svc.downSpeed = svc._fmt((rxTotal - prev.rx) / dt)
                        svc.upSpeed = svc._fmt((txTotal - prev.tx) / dt)
                    }
                }
                svc._prev = { "rx": rxTotal, "tx": txTotal, "t": now }
            }
        }
    }

    // 激活即采样，300ms 后补第二个样本得到首个速率，再回到 2s 周期
    property Timer pollTimer: PollTimer {
        active: svc.active
        period: 2000
        warmupPeriod: 300
        onTriggered: {
            netProc.command = ["cat", "/proc/net/dev"]
            netProc.running = false
            netProc.running = true
        }
    }
}
