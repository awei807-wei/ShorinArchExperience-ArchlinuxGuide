// Brain_Shell EnvyControlService — mock。GPU 切换仅状态机，无 envycontrol 调用。
import QtQuick

QtObject {
    property string currentMode: "integrated"
    property bool busy: false

    function switchMode(next) {
        if (busy || next === currentMode)
            return
        busy = true
        switchTimer.targetMode = next
        switchTimer.restart()
    }

    property Timer switchTimer: Timer {
        interval: 900
        property string targetMode: ""
        onTriggered: {
            parent.currentMode = targetMode
            parent.busy = false
        }
    }
}
