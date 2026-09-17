// Brain_Shell MemService — 真实数据。/proc/meminfo 计算 RAM 占用。
import QtQuick
import Quickshell.Io

QtObject {
    id: svc

    property bool active: false
    property real usagePercent: 0
    property string usedStr: "0"
    property string totalStr: "0"

    function _gib(bytes) {
        return (bytes / 1073741824).toFixed(1)
    }

    property Process memProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const total = Number(this.text.match(/^MemTotal:\s+(\d+)/m)?.[1] || 0)
                const avail = Number(this.text.match(/^MemAvailable:\s+(\d+)/m)?.[1] || 0)
                if (total <= 0)
                    return
                const used = total - avail
                svc.totalStr = svc._gib(total * 1024)
                svc.usedStr = svc._gib(used * 1024)
                svc.usagePercent = Math.round(used / total * 1000) / 10
            }
        }
    }

    property Timer pollTimer: Timer {
        interval: 2000
        repeat: true
        running: svc.active
        onTriggered: {
            memProc.command = ["cat", "/proc/meminfo"]
            memProc.running = false
            memProc.running = true
        }
    }
}
