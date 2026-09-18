// Brain_Shell ThermalService — 真实数据。/sys/class/hwmon 读取 CPU/GPU 温度。
import QtQuick
import Quickshell.Io
// PollTimer 经 ../qmldir 暴露：qs: 方案下同目录类型不会被自动发现
import "../"

QtObject {
    id: svc

    property bool active: false
    property real cpuTemp: 0
    property real gpuTemp: 0
    property string cpuTempStr: "—"
    property string gpuTempStr: "—"

    function _sync() {
        if (cpuTemp > 0)
            cpuTempStr = Math.round(cpuTemp) + "°C"
        if (gpuTemp > 0)
            gpuTempStr = Math.round(gpuTemp) + "°C"
    }

    property Process thermalProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                // 逐行: <chip 名> <毫摄氏度>
                let cpu = 0
                let gpu = 0
                for (const line of this.text.split("\n")) {
                    const parts = line.trim().split(/\s+/)
                    if (parts.length < 2)
                        continue
                    const chip = parts[0]
                    const temp = Number(parts[1]) / 1000
                    if (!isFinite(temp) || temp <= 0 || temp > 120)
                        continue
                    if (chip === "amdgpu" || chip === "nouveau"
                            || chip === "radeon" || chip === "i915") {
                        if (temp > gpu) gpu = temp
                    } else if (chip === "k10temp" || chip === "coretemp"
                            || chip === "cpu_thermal" || chip === "zenpower") {
                        if (temp > cpu) cpu = temp
                    }
                }
                if (cpu > 0) svc.cpuTemp = cpu
                if (gpu > 0) svc.gpuTemp = gpu
                svc._sync()
            }
        }
    }

    // 激活即采样（单次快照就有读数，无需热身）
    property Timer pollTimer: PollTimer {
        active: svc.active
        period: 2500
        onTriggered: {
            thermalProc.command = ["sh", "-c",
                "for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name 2>/dev/null);" +
                "for t in $h/temp*_input; do v=$(cat $t 2>/dev/null);" +
                "[ -n \"$v\" ] && echo \"$n $v\"; done; done"]
            thermalProc.running = false
            thermalProc.running = true
        }
    }

    Component.onCompleted: _sync()
}
