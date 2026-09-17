// Brain_Shell CpuFreqService — 真实数据。/sys cpufreq 读取频率与调速器。
import QtQuick
import Quickshell.Io

QtObject {
    id: svc

    property string curFreqStr: "—"
    property string activeProfile: "unknown"

    property Process freqProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const khz = Number(this.text.trim())
                if (khz > 0)
                    svc.curFreqStr = (khz / 1000000).toFixed(1) + " GHz"
            }
        }
    }

    property Process governorProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const gov = this.text.trim()
                if (gov !== "")
                    svc.activeProfile = gov
            }
        }
    }

    property Timer pollTimer: Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: {
            freqProc.command = ["cat",
                "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"]
            freqProc.running = false
            freqProc.running = true
            governorProc.command = ["cat",
                "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"]
            governorProc.running = false
            governorProc.running = true
        }
    }
}
