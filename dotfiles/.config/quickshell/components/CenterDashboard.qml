import QtQuick
import Quickshell
import Quickshell.Wayland
import "../vendor/brain"
import "../vendor/brain/components"
import "../vendor/brain/services/"
import "../vendor/brain/services/center/"
import "../config" as Config
import ".." as Core

// 中岛子面板宿主。唯一的几何进度是 controller.progress：
// 背景轮廓（CenterPanelShape）按当前宽高直接实例化、真实变形，
// 页面内容按最终宽度排版、独立裁切，只在展开后段淡入。
// 两者都不是卷帘裁切——动画期间底边始终是外壳自己的圆角。
PanelWindow {
    id: root

    required property var controller
    required property var modelData
    screen: modelData

    readonly property int fw: Theme.notchRadius
    readonly property int fh: Theme.notchRadius
    // PanelWindow.margins 使用整数逻辑像素；重叠量向上取整，
    // 不把小数窗口边距和未经取整的 Item 偏移混用。
    readonly property int seamOverlapPx: Math.max(1, Math.ceil(
        2 / (root.devicePixelRatio > 0 ? root.devicePixelRatio : 1)))
    readonly property int barBottom: Config.BarTuning.barMarginTop
        + Config.BarTuning.barHeight
    readonly property real seamLocalY: root.barBottom - root.margins.top
    readonly property real connectionCenterX: controller.centerCenterX > 0
        ? controller.centerCenterX : root.width / 2

    // 唯一几何进度（0..1，由 controller 动画驱动）
    readonly property real p: Math.max(0, Math.min(1, controller.progress))
    readonly property real finalPanelWidth: controller.pageWidth + 2 * root.fw
    readonly property real livePanelWidth: controller.centerWidth
        + (finalPanelWidth - controller.centerWidth) * root.p
    readonly property real livePanelHeight: Theme.dashboardHeight * root.p
    // 中岛底部当前圆角（Bar 同步），颈部接入口与其对应
    readonly property real currentBottomRadius:
        Config.BarTuning.barNotchRadius * (1 - root.p)
    readonly property real currentNeckWidth: Math.max(0,
        controller.centerWidth - 2 * root.currentBottomRadius)
    // 内容可见度：几何进度 0.85 后 smoothstep 淡入
    readonly property real contentOpacity: {
        const t = Math.max(0, Math.min(1, (root.p - 0.85) / 0.15))
        return t * t * (3 - 2 * t)
    }

    readonly property bool panelActiveOnScreen:
        controller.isScreenActive(modelData)

    color: "transparent"
    visible: controller.windowVisible && panelActiveOnScreen

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    // 窗口顶边伸入 bar 底边 seamOverlapPx，让颈部连接区能够绘制重叠带
    margins.top: Math.max(0, root.barBottom - root.seamOverlapPx)

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus:
        visible && controller.open
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // 点击 bar 以外区域关闭
    MouseArea {
        anchors.fill: parent
        onClicked: controller.close()
    }

    // ── 面板背景轮廓：当前几何直接实例化，不进任何 clip 容器 ──────────
    CenterPanelShape {
        id: shellOutline

        visible: root.p > 0.001
        x: root.connectionCenterX - width / 2
        y: root.seamLocalY
        width: root.livePanelWidth
        height: root.livePanelHeight
        color: Theme.background
        neckWidth: root.currentNeckWidth
        radius: Config.Theme.radiusMedium
        flare: root.fh
    }

    // ── 补缝带：只在岛底与颈部接入口的共有区域内的小范围重叠 ──────────
    // 宽度不超过真实接入口（currentNeckWidth），progress 归零即消失。
    Rectangle {
        id: neck

        visible: shellOutline.visible
        x: root.connectionCenterX - width / 2
        y: 0
        width: root.currentNeckWidth
        height: root.seamLocalY + 1
        color: Theme.background
    }

    // ── 页面内容：始终按最终宽度排版，独立裁切，后段淡入 ──────────────
    // 裁切只作用于内容；可见度由 contentOpacity（p≥0.85 才出现）控制，
    // 关闭时先快速淡出，再让空壳收回——不会看到卡片被拦腰切开。
    Item {
        id: contentStage

        x: root.connectionCenterX - width / 2
        y: root.seamLocalY
        width: root.finalPanelWidth
        height: root.livePanelHeight
        clip: true
        visible: root.p > 0.001
        opacity: root.contentOpacity
        enabled: controller.open && root.p > 0.999

        Item {
            // 内容按最终几何排版，不随揭示高度挤压
            anchors.fill: parent
            anchors.topMargin: root.fh + 8
            anchors.leftMargin: root.fw + 8
            anchors.rightMargin: root.fw + 8
            anchors.bottomMargin: 8

            Column {
                anchors.fill: parent
                spacing: 0

                TabSwitcher {
                    id: tabBar

                    orientation: "horizontal"
                    width: parent.width
                    currentPage: controller.page
                    model: [
                        { key: "home",     icon: "󰋜", label: "Home" },
                        { key: "stats",    icon: "󰻠", label: "System" },
                        { key: "kanban",   icon: "󰄬", label: "Tasks" }
                    ]
                    onPageChanged: key => controller.showPage(key)
                }

                Item {
                    id: pageArea

                    focus: true
                    width: parent.width
                    height: parent.height - tabBar.height

                    Keys.onEscapePressed: controller.close()

                    Item {
                        anchors.fill: parent
                        visible: controller.page === "home"
                        DashHome { anchors.fill: parent }
                    }

                    Item {
                        anchors.fill: parent
                        visible: controller.page === "stats"
                        DashStats { anchors.fill: parent }
                    }

                    Item {
                        anchors.fill: parent
                        visible: controller.page === "kanban"
                        KanbanBoard { anchors.fill: parent }
                    }
                }
            }
        }
    }
}
