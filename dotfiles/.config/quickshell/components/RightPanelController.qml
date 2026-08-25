import "../config" as Config
import QtQuick

// 统一管理右岛两个入口、当前页、触发屏幕、共享外壳进度和固定外窗
// 生命周期。Bar、面板 viewport 与关闭 mask 只消费同一份几何状态。
Item {
    id: root

    readonly property int controlsPage: 0
    readonly property int notificationsPage: 1
    property bool rightPanelOpen: false
    property string rightPanelPage: "control"
    property real rightPanelProgress: 0
    property bool windowVisible: false
    property bool reducedMotion: false
    property int animationDuration: Config.BarTuning.panelShellDuration
    property int hideDelay: Config.BarTuning.panelWindowHideDelay
    property real baseRightWidth: Config.BarTuning.rightPanelNeckWidth
    property real targetRightWidth: Config.BarTuning.rightPanelNeckWidth
    property var activeScreen: null

    readonly property int page: rightPanelPage === "history"
        ? notificationsPage : controlsPage
    readonly property bool open: rightPanelOpen
    readonly property real progress: rightPanelProgress
    readonly property bool closing: windowVisible && !open
    readonly property bool animationRunning: shellAnimation.running
    readonly property real currentRightWidth: Math.round(
        baseRightWidth
        + (targetRightWidth - baseRightWidth)
            * Math.max(0, Math.min(1, rightPanelProgress))
    )

    width: 0
    height: 0
    visible: false

    function normalizedPage(targetPage) {
        return targetPage === notificationsPage
            ? notificationsPage : controlsPage
    }

    function isUsableWidth(candidate) {
        return candidate !== undefined && candidate !== null
            && isFinite(candidate) && candidate > 0
    }

    function isScreenActive(candidate) {
        return candidate === undefined || candidate === null
            || activeScreen === null || activeScreen === candidate
    }

    function updateGeometry(sourceBaseRightWidth,
                            sourceTargetRightWidth,
                            sourceScreen) {
        if (isUsableWidth(sourceBaseRightWidth)) {
            baseRightWidth = Math.min(
                Config.BarTuning.rightPanelNeckWidth,
                Math.max(1, sourceBaseRightWidth)
            )
        }
        if (isUsableWidth(sourceTargetRightWidth)) {
            targetRightWidth = Math.min(
                Config.BarTuning.rightPanelNeckWidth,
                Math.max(baseRightWidth, sourceTargetRightWidth)
            )
        } else {
            targetRightWidth = Math.min(
                Config.BarTuning.rightPanelNeckWidth,
                Math.max(baseRightWidth, targetRightWidth)
            )
        }
        if (sourceScreen !== undefined && sourceScreen !== null)
            activeScreen = sourceScreen
    }

    function showPage(targetPage, sourceBaseRightWidth,
                      sourceTargetRightWidth, sourceScreen) {
        const screenChanged = sourceScreen !== undefined
            && sourceScreen !== null
            && activeScreen !== null
            && activeScreen !== sourceScreen

        updateGeometry(sourceBaseRightWidth,
                       sourceTargetRightWidth,
                       sourceScreen)
        rightPanelPage = normalizedPage(targetPage) === notificationsPage
            ? "history" : "control"
        if (screenChanged) {
            closeTimer.stop()
            shellAnimation.stop()
            rightPanelProgress = 0
        }
        if (!rightPanelOpen) {
            rightPanelOpen = true
        } else if (screenChanged) {
            syncShellProgress()
        }
    }

    function togglePage(targetPage, sourceBaseRightWidth,
                        sourceTargetRightWidth, sourceScreen) {
        const target = normalizedPage(targetPage)
        if (rightPanelOpen && page === target
                && isScreenActive(sourceScreen)) {
            close()
            return
        }
        showPage(target, sourceBaseRightWidth,
                 sourceTargetRightWidth, sourceScreen)
    }

    function close() {
        rightPanelOpen = false
    }

    function finishClose() {
        if (rightPanelOpen || rightPanelProgress > 0.001)
            return
        closeTimer.stop()
        windowVisible = false
    }

    function scheduleWindowHide() {
        if (rightPanelOpen)
            return
        if (hideDelay <= 0)
            finishClose()
        else
            closeTimer.restart()
    }

    function syncShellProgress() {
        closeTimer.stop()
        shellAnimation.stop()

        const targetProgress = rightPanelOpen ? 1 : 0
        if (rightPanelOpen)
            windowVisible = true

        if (reducedMotion || animationDuration <= 0) {
            rightPanelProgress = targetProgress
            if (!rightPanelOpen)
                finishClose()
            return
        }

        if (Math.abs(rightPanelProgress - targetProgress) <= 0.0001) {
            rightPanelProgress = targetProgress
            if (!rightPanelOpen)
                scheduleWindowHide()
            return
        }

        shellAnimation.from = rightPanelProgress
        shellAnimation.to = targetProgress
        shellAnimation.duration = Math.max(1, animationDuration)
        shellAnimation.restart()
    }

    onRightPanelOpenChanged: syncShellProgress()
    onReducedMotionChanged: {
        if (reducedMotion)
            syncShellProgress()
    }

    Component.onCompleted: {
        rightPanelProgress = rightPanelOpen ? 1 : 0
        windowVisible = rightPanelOpen
    }

    NumberAnimation {
        id: shellAnimation

        target: root
        property: "rightPanelProgress"
        easing.type: Easing.InOutCubic
        onFinished: {
            if (!root.rightPanelOpen
                    && root.rightPanelProgress <= 0.001)
                root.scheduleWindowHide()
        }
    }

    Timer {
        id: closeTimer

        interval: Math.max(0, root.hideDelay)
        onTriggered: root.finishClose()
    }
}
