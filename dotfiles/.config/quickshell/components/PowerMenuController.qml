import "../config" as Config
import QtQuick

// 右侧电源菜单控制器 — 管理电源菜单开闭状态、屏幕目标和单一进度时钟
Item {
    id: root

    property bool open: false
    property real powerMenuProgress: 0
    property bool windowVisible: false
    property bool reducedMotion: false
    property var activeScreen: null

    property int animationDuration: Config.BarTuning.panelShellDuration
    property int hideDelay: Config.BarTuning.panelWindowHideDelay

    // 与 Brain_Shell PowerMenu 保持一致的尺寸
    readonly property int menuWidth: 230
    readonly property int menuHeight: 274

    readonly property bool animationRunning: shellAnimation.running

    function isScreenActive(candidate) {
        return candidate === undefined || candidate === null
            || activeScreen === null || activeScreen === candidate
    }

    function show(sourceScreen) {
        if (sourceScreen !== undefined && sourceScreen !== null)
            activeScreen = sourceScreen
        if (!open)
            open = true
    }

    function toggle(sourceScreen) {
        if (open && isScreenActive(sourceScreen)) {
            close()
            return
        }
        show(sourceScreen)
    }

    function close() {
        open = false
    }

    function finishClose() {
        if (open)
            return
        closeTimer.stop()
        windowVisible = false
    }

    function scheduleWindowHide() {
        if (open)
            return
        if (hideDelay <= 0)
            finishClose()
        else
            closeTimer.restart()
    }

    function syncState() {
        closeTimer.stop()
        shellAnimation.stop()

        if (open)
            windowVisible = true

        const targetProgress = open ? 1 : 0
        const distance = Math.abs(targetProgress - powerMenuProgress)
        if (distance <= 0.0001) {
            powerMenuProgress = targetProgress
            if (!open)
                scheduleWindowHide()
            return
        }

        if (reducedMotion || animationDuration <= 0) {
            powerMenuProgress = targetProgress
            if (!open)
                finishClose()
            return
        }

        shellAnimation.from = powerMenuProgress
        shellAnimation.to = targetProgress
        shellAnimation.duration = Math.max(1, animationDuration)
        shellAnimation.restart()
    }

    onOpenChanged: syncState()
    onReducedMotionChanged: {
        if (reducedMotion)
            syncState()
    }

    NumberAnimation {
        id: shellAnimation

        target: root
        property: "powerMenuProgress"
        easing.type: Easing.OutCubic
        onFinished: {
            if (!root.open && root.powerMenuProgress <= 0.001)
                root.scheduleWindowHide()
        }
    }

    Timer {
        id: closeTimer

        interval: Math.max(0, root.hideDelay)
        onTriggered: root.finishClose()
    }
}