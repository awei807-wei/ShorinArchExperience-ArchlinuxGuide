import QtQuick
import Quickshell
import Quickshell.Wayland
import "../vendor/brain"
import "../vendor/brain/shapes"
import "../vendor/brain/components"
import "../vendor/brain/services/"
import "../vendor/brain/services/center/"
import "../config" as Config

// 中岛子面板宿主 — Brain_Shell Dashboard.qml (MIT) 的原样移植：
// sizer 为 clip 视口，宽度（页面宽 ↔ 中岛宽）与高度（notchHeight/2 ↔
// dashboardHeight）以同一条 InOutCubic Behavior 同步开合；
// PopupShape 随 sizer 当前尺寸重绘；内容仅在 sizer 内做透明度淡入淡出。
PanelWindow {
    id: root

    required property var controller
    required property var modelData
    screen: modelData

    readonly property int fw: Theme.notchRadius
    readonly property int fh: Theme.notchRadius
    readonly property int animDuration: controller.animationDuration

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
    // sizer 顶边与 bar 底边齐平（Brain 原方案：Theme.notchHeight）
    margins.top: Config.BarTuning.barMarginTop + Config.BarTuning.barHeight

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

    Item {
        id: sizer

        // 水平对齐中岛中心（controller 记录点击时中岛中心的屏幕坐标；
        // 中岛无偏移时与 Brain 的 horizontalCenter 等价）
        x: root.connectionCenterX > 0
            ? root.connectionCenterX - width / 2
            : (parent.width - width) / 2
        anchors.top: parent.top
        clip: true

        // Brain: dashboardOpen ? dashboardPageWidth + 2*fw : cNotchMinWidth + 2*fw
        width: controller.open
            ? controller.pageWidth + 2 * root.fw
            : controller.centerWidth + 2 * root.fw
        // Brain: dashboardOpen ? dashboardHeight : notchHeight / 2
        height: controller.open
            ? Theme.dashboardHeight
            : Theme.notchHeight / 2

        Behavior on width {
            NumberAnimation {
                duration: root.animDuration
                easing.type: Easing.InOutCubic
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: root.animDuration
                easing.type: Easing.InOutCubic
            }
        }

        // 吞掉面板内部点击，避免穿透到关闭层
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // Brain 原版 PopupShape：随 sizer 当前尺寸重绘
        PopupShape {
            anchors.fill: parent
            attachedEdge: "top"
            color: Theme.background
            radius: Theme.cornerRadius
            flareWidth: root.fw
            flareHeight: root.fh
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
