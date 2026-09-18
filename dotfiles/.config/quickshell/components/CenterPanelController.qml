import QtQuick
import "../vendor/brain"

// 中岛子面板控制器 — Brain_Shell Popups 单例的开合状态在我们这边由
// 控制器持有；开合动画收敛为单一进度时钟（centerPanelProgress），
// bar 轮廓与面板壳体都消费同一份进度，缺口边缘与面板边缘逐帧同值，
// 消除两个窗口各自跑 Behavior 造成的收回错拍（右岛同款架构）。
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

    // 开合进度 0..1：0 = 收拢（岛宽），1 = 展开（页宽）
    property real centerPanelProgress: 0

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
        shellAnimation.stop()
        Popups.dashboardOpen = open
        Popups.dashboardPage = page
        if (open)
            windowVisible = true

        const targetProgress = open ? 1 : 0
        if (Math.abs(centerPanelProgress - targetProgress) <= 0.0001) {
            centerPanelProgress = targetProgress
            if (!open)
                scheduleWindowHide()
            return
        }

        shellAnimation.from = centerPanelProgress
        shellAnimation.to = targetProgress
        shellAnimation.duration = Math.max(1, animationDuration)
        shellAnimation.restart()
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

    // 单一进度时钟：开合方向共用，开/收都由这条动画驱动
    NumberAnimation {
        id: shellAnimation

        target: root
        property: "centerPanelProgress"
        easing.type: Easing.InOutCubic
        onFinished: {
            if (!root.open && root.centerPanelProgress <= 0.001)
                root.scheduleWindowHide()
        }
    }

    Timer {
        id: closeTimer

        // 只覆盖 hideDelay：本计时器在 shellAnimation.onFinished 之后才
        // 启动（动画时长已消耗完毕），不再沿用旧方案的 anim + delay，
        // 否则窗口会在面板缩没后滞留一个动画时长，岛底直角迟迟不复原
        interval: Math.max(0, root.hideDelay)
        onTriggered: root.finishClose()
    }

    Component.onCompleted: {
        Popups.dashboardOpen = open
        windowVisible = open
        centerPanelProgress = open ? 1 : 0
    }
}
