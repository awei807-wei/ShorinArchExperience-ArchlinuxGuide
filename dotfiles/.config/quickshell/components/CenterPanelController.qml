import QtQuick
import "../vendor/brain"

// 中岛子面板控制器 — Brain_Shell Popups 单例的开合状态在我们这边由
// 控制器持有；动画本身住在 Dashboard 的 Behavior 与 Bar 的 cWidth
// Behavior 里（Brain 原方案），控制器只负责状态与窗口生命周期。
Item {
    id: root

    readonly property int homePage: 0
    readonly property int systemPage: 1
    readonly property int tasksPage: 2
    readonly property int appsPage: 3

    property bool open: false
    property string page: "home"
    property int animationDuration: 300
    property int hideDelay: 20
    property bool windowVisible: false
    property var activeScreen: null

    // 打开面板的锚点宽度：中岛实际宽度（由 Bar 注入）
    property real centerWidth: 300
    // 中岛中心的屏幕 X 坐标（由 Bar 注入，面板水平对齐中岛）
    property real centerCenterX: 0

    readonly property int pageWidth: 900

    function isScreenActive(candidate) {
        return candidate === undefined || candidate === null
            || activeScreen === null || activeScreen === candidate
    }

    function showPage(targetPage, sourceScreen, sourceCenterX) {
        if (sourceScreen !== undefined && sourceScreen !== null)
            activeScreen = sourceScreen
        if (sourceCenterX !== undefined && sourceCenterX !== null)
            centerCenterX = sourceCenterX
        page = targetPage
        if (!open)
            open = true
    }

    function togglePage(targetPage, sourceScreen, sourceCenterX) {
        if (open && page === targetPage && isScreenActive(sourceScreen)) {
            close()
            return
        }
        showPage(targetPage, sourceScreen, sourceCenterX)
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
        Popups.dashboardOpen = open
        Popups.dashboardPage = page
        if (open)
            windowVisible = true
        else
            scheduleWindowHide()
    }

    onOpenChanged: syncState()
    onPageChanged: Popups.dashboardPage = page

    Connections {
        target: Popups
        function onDashboardOpenChanged() {
            if (!Popups.dashboardOpen && root.open)
                root.open = false
        }
    }

    Timer {
        id: closeTimer

        interval: Math.max(0, root.animationDuration + root.hideDelay)
        onTriggered: root.finishClose()
    }

    Component.onCompleted: {
        Popups.dashboardOpen = open
        windowVisible = open
    }
}
