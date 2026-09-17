import QtQuick
import "../vendor/brain"

// 中岛子面板控制器。progress 是唯一的几何进度：打开、关闭、中途反向
// 都操作同一个值；Bar（岛底圆角）与 Dashboard（外壳宽高）全部由它推导。
Item {
    id: root

    readonly property int homePage: 0
    readonly property int systemPage: 1
    readonly property int tasksPage: 2
    readonly property int appsPage: 3

    property bool open: false
    property string page: "home"
    property int openDuration: 300
    property int closeDuration: 240
    property int hideDelay: 20
    property real progress: 0
    property bool windowVisible: false
    property bool reducedMotion: false
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
        if (open || progress > 0.001)
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
        progressAnimation.stop()
        Popups.dashboardOpen = open
        Popups.dashboardPage = page
        if (open)
            windowVisible = true

        const duration = open ? openDuration : closeDuration
        const target = open ? 1 : 0
        if (reducedMotion || duration <= 0
                || Math.abs(progress - target) <= 0.0001) {
            progress = target
            if (!open)
                scheduleWindowHide()
            return
        }

        progressAnimation.from = progress
        progressAnimation.to = target
        progressAnimation.duration = duration
        progressAnimation.restart()
    }

    onOpenChanged: syncState()
    onReducedMotionChanged: {
        if (reducedMotion)
            syncState()
    }
    onPageChanged: Popups.dashboardPage = page

    Connections {
        target: Popups
        function onDashboardOpenChanged() {
            if (!Popups.dashboardOpen && root.open)
                root.open = false
        }
    }

    NumberAnimation {
        id: progressAnimation

        target: root
        property: "progress"
        easing.type: Easing.InOutCubic
        onFinished: {
            if (!root.open)
                root.scheduleWindowHide()
        }
    }

    Timer {
        id: closeTimer

        interval: Math.max(0, root.closeDuration + root.hideDelay)
        onTriggered: root.finishClose()
    }

    Component.onCompleted: {
        progress = open ? 1 : 0
        windowVisible = open
    }
}
