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

    readonly property int fw: Theme.notchRadius
    readonly property int fh: Theme.notchRadius
    readonly property int animDuration: controller.animationDuration
    // 接缝重叠量：2 物理像素（换算为逻辑像素），仅供颈部吸收双窗口边缘误差
    readonly property real seamOverlapPx:
        2 / (Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1)

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
    margins.top: Config.BarTuning.barMarginTop
        + Config.BarTuning.barHeight - root.seamOverlapPx

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
    // 宽度固定为中岛宽（+ flare），绝不横跨面板主体宽度。
    Rectangle {
        id: neck

        visible: controller.windowVisible && root.panelActiveOnScreen
        x: sizer.x
        y: 0
        width: controller.centerWidth + 2 * root.fw
        height: root.fh + root.seamOverlapPx
        color: Theme.background
    }

    Item {
        id: sizer

        // 水平对齐中岛中心（controller 记录点击时中岛中心的屏幕坐标）
        x: controller.centerCenterX > 0
            ? controller.centerCenterX - width / 2
            : (parent.width - width) / 2
        // 顶边固定在 bar 底边（窗口已上移 overlap，这里补回）
        anchors.top: parent.top
        anchors.topMargin: root.seamOverlapPx
        clip: true

        width: controller.open
            ? controller.pageWidth + 2 * root.fw
            : controller.centerWidth + 2 * root.fw
        // 高度下限保证 PopupShape 凹角之下始终有主体实心，
        // 中央颈部任何帧都不会露出空腔
        height: controller.open
            ? Theme.dashboardHeight
            : root.fh + 4

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

        // 顶部熔接轮廓（凹角 flare 与 bar 无缝衔接）。
        // 小高度帧 clamp：凹角永远小于主体高度，中央实心区不为零，
        // 避免揭示动画早期颈部中央出现空腔漏底。
        PopupShape {
            anchors.fill: parent
            attachedEdge: "top"
            color: Theme.background
            radius: Math.max(0, Math.min(
                Theme.cornerRadius, sizer.height / 2))
            flareWidth: root.fw
            flareHeight: Math.max(0, Math.min(
                root.fh, sizer.height - 4))
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
