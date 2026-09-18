import Quickshell
import QtQuick
import "vendor/brain"

// spectrum-probe.qml — CavaService 内部状态探针（调试用）。
//   quickshell -p spectrum-probe.qml
ShellRoot {
    Timer {
        interval: 800
        repeat: true
        running: true
        onTriggered: console.log("[probe]",
            "active=" + CavaService.active,
            "sink=" + CavaService.sinkName,
            "launcher=" + CavaService._launcherPath,
            "worker=" + CavaService._workerPath,
            "pid=" + CavaService.spectrumProc.processId,
            "target0=" + (CavaService.targetSpectrum.length
                ? CavaService.targetSpectrum.reduce((a, b) => Math.max(a, b), 0).toFixed(3)
                : "none"))
    }
    Timer {
        interval: 5000
        running: true
        onTriggered: {
            CavaService.active = false
            Qt.exit(0)
        }
    }
    Component.onCompleted: CavaService.active = true
}
