// Brain_Shell CpuFreqService — 真实数据。/sys cpufreq 读取频率与调速器。
import QtQuick
import Quickshell.Io
// PollTimer 经 ../qmldir 暴露：qs: 方案下同目录类型不会被自动发现
import "../"

QtObject {
    id: svc

    // 与其他采集服务同款门控：只在面板展开期间轮询，不再常驻后台
    property bool active: false
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

    // 激活即采样（单次快照就有读数，无需热身）
    property Timer pollTimer: PollTimer {
        active: svc.active
        period: 3000
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
