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
    // 减少动画：开合直接落位到进度终点，仍走同一套关闭生命周期
    property bool reducedMotion: false
    property bool windowVisible: false
    property var activeScreen: null

    // 打开面板的锚点宽度：中岛实际宽度（由 Bar 注入）
    property real centerWidth: 300
    // 中岛中心的屏幕 X 坐标（由 Bar 注入，面板水平对齐中岛）
    property real centerCenterX: 0

    // 开合进度 0..1：0 = 收拢（岛宽），1 = 展开（页宽）
    property real centerPanelProgress: 0

    readonly property int pageWidth: 900
    // 面板展开后的固定高度：外部点击捕获层用它扣除面板矩形
    readonly property int pageHeight: Theme.dashboardHeight

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
        const distance = Math.abs(targetProgress - centerPanelProgress)
        if (distance <= 0.0001) {
            centerPanelProgress = targetProgress
            if (!open)
                scheduleWindowHide()
            return
        }

        // 减少动画：直接落位，仍走同一套关闭生命周期
        if (reducedMotion || animationDuration <= 0) {
            centerPanelProgress = targetProgress
            if (!open)
                scheduleWindowHide()
            return
        }

        shellAnimation.from = centerPanelProgress
        shellAnimation.to = targetProgress
        // 按剩余行程缩放时长：中途反向时小幅动作不再拖满全程；
        // 下限 60ms 避免极小动作闪跳。这是行程等比而非严格速度连续。
        // 开 280ms / 关 220ms 为 OutQuad 下的建议起点，验收后可微调
        const baseDuration = open ? 280 : 220
        shellAnimation.duration = Math.max(
            60, Math.round(baseDuration * distance))
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
        // OutQuad：起步即有可见位移。InOutCubic 从零速加速，300ms 下
        // 前 50ms 位移不足 10px，体感为"点了没反应"（右岛同款结论）
        easing.type: Easing.OutQuad
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
