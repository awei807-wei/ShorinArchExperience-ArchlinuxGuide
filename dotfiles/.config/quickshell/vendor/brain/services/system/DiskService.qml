// Brain_Shell DiskService — 真实数据。df -P 采集物理分区占用。
import QtQuick
import Quickshell.Io

QtObject {
    id: svc

    property bool active: false

    readonly property var disks: __disks

    // 内部可写缓冲，disks 以 readonly 暴露给面板
    property var __disks: []

    property Process diskProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const result = []
                for (const line of this.text.split("\n")) {
                    const p = line.trim().split(/\s+/)
                    if (p.length < 6 || !p[0].startsWith("/dev"))
                        continue
                    const total = Number(p[1])
                    const used = Number(p[2])
                    const avail = Number(p[3])
                    if (!(total > 0 && used >= 0 && avail >= 0))
                        continue
                    const gib = v => (v / 1073741824).toFixed(0) + "G"
                    result.push({
                        "source": p[0],
                        "mount": p[5],
                        "usedPct": Math.round(used / (used + avail) * 100),
                        "usedStr": gib(used),
                        "totalStr": gib(total)
                    })
                    if (result.length >= 6)
                        break
                }
                svc.__disks = result
            }
        }
    }

    property Timer pollTimer: Timer {
        interval: 5000
        repeat: true
        running: svc.active
        onTriggered: {
            diskProc.command = ["sh", "-c",
                "df -P -B1 -x tmpfs -x devtmpfs -x efivarfs | tail -n +2"]
            diskProc.running = false
            diskProc.running = true
        }
    }
}
