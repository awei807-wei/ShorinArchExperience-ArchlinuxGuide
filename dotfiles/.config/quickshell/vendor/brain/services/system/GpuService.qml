// Brain_Shell GpuService — 真实数据。amdgpu sysfs 读取 iGPU 占用与频率。
import QtQuick
import Quickshell.Io

QtObject {
    id: svc

    property bool active: false
    property string envyMode: "integrated"

    readonly property QtObject igpu: QtObject {
        property real freqPercent: 0
        property string curMhz: "—"
    }

    readonly property QtObject dgpu: QtObject {
        property bool active: false
        property real usagePercent: 0
        property string usedVram: "0G"
        property string totalVram: "0G"
    }

    property Process busyProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const pct = Number(this.text.trim())
                if (isFinite(pct) && pct >= 0 && pct <= 100)
                    svc.igpu.freqPercent = Math.round(pct)
            }
        }
    }

    property Timer pollTimer: Timer {
        interval: 2000
        repeat: true
        running: svc.active
        onTriggered: {
            busyProc.command = ["sh", "-c",
                "for c in /sys/class/drm/card[0-9]*; do" +
                "[ -f \"$c/device/gpu_busy_percent\" ] && cat \"$c/device/gpu_busy_percent\" && break; done"]
            busyProc.running = false
            busyProc.running = true
        }
    }
}
