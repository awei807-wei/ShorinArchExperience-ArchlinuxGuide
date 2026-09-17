// Brain_Shell NetService — 真实数据。/proc/net/dev 差分计算上下行速率。
import QtQuick
import Quickshell.Io

QtObject {
    id: svc

    property bool active: false
    property string iface: ""
    property string upSpeed: "0 B/s"
    property string downSpeed: "0 B/s"
    property var _prev: null

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
                const prev = svc._prev
                if (prev && rxTotal >= prev.rx && txTotal >= prev.tx) {
                    svc.downSpeed = svc._fmt((rxTotal - prev.rx) / 2)
                    svc.upSpeed = svc._fmt((txTotal - prev.tx) / 2)
                }
                svc._prev = { "rx": rxTotal, "tx": txTotal }
            }
        }
    }

    property Timer pollTimer: Timer {
        interval: 2000
        repeat: true
        running: svc.active
        onTriggered: {
            netProc.command = ["cat", "/proc/net/dev"]
            netProc.running = false
            netProc.running = true
        }
    }
}
