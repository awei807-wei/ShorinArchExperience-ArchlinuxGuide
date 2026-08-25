import "../config" as Config
import QtQuick

// 统一管理右岛两个入口、当前页和退场期间的固定外窗生命周期。
// 轮廓动画由 UnifiedRightPanel 持有；状态机只在退场真正完成后隐藏窗口。
Item {
    id: root

    readonly property int controlsPage: 0
    readonly property int notificationsPage: 1
    // 对外状态与落地清单保持一致；整数 page/open 只作为现有调用方的
    // 只读兼容视图，避免同时维护两套可写状态。
    property bool rightPanelOpen: false
    property string rightPanelPage: "control"
    readonly property int page: rightPanelPage === "history"
        ? notificationsPage : controlsPage
    readonly property bool open: rightPanelOpen
    property bool windowVisible: false
    property bool reducedMotion: false
    property int hideDelay: Math.max(
        Config.BarTuning.panelHeightCloseDuration + 20,
        Config.BarTuning.panelWidthCloseDuration + 70
    ) + 400
    readonly property bool closing: windowVisible && !open

    width: 0
    height: 0
    visible: false

    function normalizedPage(targetPage) {
        return targetPage === notificationsPage ? notificationsPage : controlsPage
    }

    function showPage(targetPage) {
        rightPanelPage = normalizedPage(targetPage) === notificationsPage
            ? "history" : "control"
        if (!rightPanelOpen)
            rightPanelOpen = true
    }

    function togglePage(targetPage) {
        const target = normalizedPage(targetPage)
        if (rightPanelOpen && page === target) {
            close()
            return
        }
        showPage(target)
    }

    function close() {
        rightPanelOpen = false
    }

    // 面板实例完成退场时调用。若期间已经重新打开，过期回报不会
    // 隐藏窗口；fallback Timer 只处理屏幕热插拔等没有完成信号的情况。
    function finishClose() {
        if (rightPanelOpen)
            return
        closeTimer.stop()
        windowVisible = false
    }

    onRightPanelOpenChanged: {
        if (rightPanelOpen) {
            closeTimer.stop()
            windowVisible = true
        } else if (windowVisible) {
            if (reducedMotion || hideDelay <= 0)
                finishClose()
            else
                closeTimer.restart()
        }
    }

    onReducedMotionChanged: {
        if (reducedMotion && closing) {
            finishClose()
        }
    }

    Timer {
        id: closeTimer

        interval: Math.max(0, root.hideDelay)
        onTriggered: {
            root.finishClose()
        }
    }
}
