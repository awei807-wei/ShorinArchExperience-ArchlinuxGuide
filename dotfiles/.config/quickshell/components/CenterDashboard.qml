import QtQuick
import Quickshell
import Quickshell.Wayland
import "../vendor/brain"
import "../vendor/brain/shapes"
import "../vendor/brain/components"
import "../vendor/brain/services/"
import "../vendor/brain/services/center/"
import "../config" as Config
import ".." as Core

// 中岛子面板宿主 — 移植自 Brain_Shell Dashboard.qml (MIT)。
// 全屏透明 PanelWindow，sizer 顶部水平居中锚定在 bar 下缘；
// 开合动画为宽高同时过渡（Brain 原方案），内容淡入淡出。
PanelWindow {
    id: root

    required property var controller
    required property var modelData
    screen: modelData

    readonly property int fw: Theme.notchRadius
    readonly property int fh: Theme.notchRadius
    readonly property int animDuration: controller.animationDuration
    // PanelWindow.margins 使用整数逻辑像素；重叠量向上取整，
    // 不把小数窗口边距和未经取整的 Item 偏移混用。
    readonly property int seamOverlapPx: Math.max(1, Math.ceil(
        2 / (root.devicePixelRatio > 0 ? root.devicePixelRatio : 1)))
    readonly property int barBottom: Config.BarTuning.barMarginTop
        + Config.BarTuning.barHeight
    readonly property real seamLocalY: root.barBottom - root.margins.top
    readonly property real connectionCenterX: controller.centerCenterX > 0
        ? controller.centerCenterX : root.width / 2
    readonly property int closedSizerHeight: root.fh + 4

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

    // ── 连接区（颈部）─────────────────────────────────────────────
    // 职责：动画全程保持对 bar 底边与面板主体之间过渡带的覆盖。
    // 不参与 clip、淡入、位移——它与 sizer 是兄弟节点，独立于揭示动画。
    // 仅覆盖中岛底部始终实心的内区。桥始终以连接中心定位，
    // 不跟随正在扩展的 sizer 左边缘，也不填平外侧圆角。
    Rectangle {
        id: neck

        visible: sizer.visible
        x: root.connectionCenterX - width / 2
        y: 0
        width: Math.max(0, controller.centerWidth
            - 2 * Config.BarTuning.barNotchRadius)
        height: root.seamLocalY + 1
        color: Theme.background
    }

    Item {
        id: sizer

        // 水平对齐中岛中心（controller 记录点击时中岛中心的屏幕坐标）
        x: root.connectionCenterX - width / 2
        // 顶边固定在 bar 底边（窗口已上移 overlap，这里补回）
        anchors.top: parent.top
        anchors.topMargin: root.seamLocalY
        clip: true
        // 外窗保留到 hideDelay 结束，但收起端点不再显示残留薄片。
        visible: controller.open || height > root.closedSizerHeight + 0.001

        width: controller.open
            ? controller.pageWidth + 2 * root.fw
            : controller.centerWidth + 2 * root.fw
        // 小高度路径还必须满足 height - radius >= flareHeight。
        height: controller.open
            ? Theme.dashboardHeight
            : root.closedSizerHeight

        Behavior on width {
            enabled: !Core.TopBarState.reducedMotion
            NumberAnimation {
                duration: root.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            enabled: !Core.TopBarState.reducedMotion
            NumberAnimation {
                duration: root.animDuration
                easing.type: Easing.OutCubic
            }
        }

        // 吞掉面板内部点击，避免穿透到关闭层
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // 保留现有外壳样式；限制上下弧之间的直边不得反向。
        // vendor 的几何属性是 int，因此显式 floor 防止 round 越界。
        PopupShape {
            id: panelShape
            anchors.fill: parent
            attachedEdge: "top"
            color: Theme.background
            radius: Math.max(0, Math.floor(Math.min(
                Theme.cornerRadius,
                sizer.height - panelShape.flareHeight,
                (sizer.width - 2 * panelShape.flareWidth) / 2)))
            flareWidth: root.fw
            flareHeight: Math.max(0, Math.floor(Math.min(
                root.fh, sizer.height - 4)))
        }

        Item {
            id: content

            anchors {
                fill: parent
                topMargin: root.fh + 8
                leftMargin: root.fw + 8
                rightMargin: root.fw + 8
                bottomMargin: 8
            }

            opacity: controller.open ? 1 : 0
            enabled: controller.open
            Behavior on opacity {
                NumberAnimation {
                    duration: controller.open
                        ? root.animDuration * 0.5
                        : root.animDuration * 0.15
                }
            }

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
