import QtQuick
import Quickshell
import Quickshell.Wayland
import "../vendor/brain"
import "../vendor/brain/shapes"
import "../vendor/brain/components"
import "../vendor/brain/services/"
import "../vendor/brain/services/center/"
import "../config" as Config

// 中岛子面板宿主 — Brain_Shell Dashboard.qml (MIT) 改良移植：
// sizer 为 clip 视口，宽/高由控制器的单一进度时钟（centerPanelProgress）
// 线性插值驱动——与 bar 缺口共用同一份进度，收回时边缘逐帧同值不错拍；
// 收拢终点高度为 0（面板在窗口隐藏前已完全消失），宽度始终 ≥ 中岛宽；
// PopupShape 为平顶矩形（无凹角耳朵），顶边与中岛底边同宽直接延续，
// 窗口顶边与 bar 底边 2px 同色重叠吸收接缝；
// 内容仅在 sizer 内做透明度淡入淡出。
PanelWindow {
    id: root

    required property var controller
    required property var modelData
    screen: modelData

    readonly property int fw: Theme.notchRadius
    readonly property int fh: Theme.notchRadius
    readonly property int animDuration: controller.animationDuration

    // 归一化的开合进度（单一进度时钟的消费入口）
    readonly property real p:
        Math.max(0, Math.min(1, controller.centerPanelProgress))

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
    // 窗口顶边伸入 bar 底边 2 逻辑像素：面板矩形与中岛底边同色重叠，
    // 吸收双窗口接缝，连接处不可见
    margins.top: Math.max(0, Config.BarTuning.barMarginTop
        + Config.BarTuning.barHeight - 2)

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
        x: controller.centerCenterX > 0
            ? controller.centerCenterX - width / 2
            : (parent.width - width) / 2
        anchors.top: parent.top
        clip: true

        // 与 bar 缺口共用同一份进度时钟：
        // 宽度在中岛宽 ↔ 页宽之间插值（与 Bar.centerPanelCWidth 同式，
        // 逐帧同值）；高度在 0 ↔ dashboardHeight 之间插值，
        // 收拢时面板在窗口隐藏前已完全缩没，不再与岛底抢拍
        width: controller.centerWidth
            + (controller.pageWidth - controller.centerWidth)
              * Math.max(0, Math.min(1, controller.centerPanelProgress))
        height: Theme.dashboardHeight
            * Math.max(0, Math.min(1, controller.centerPanelProgress))

        // 吞掉面板内部点击，避免穿透到关闭层
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // 平顶矩形：无凹角耳朵，顶边与中岛底边同宽直接延续
        PopupShape {
            anchors.fill: parent
            attachedEdge: "top"
            color: Theme.background
            radius: Theme.cornerRadius
            flareWidth: 0
            flareHeight: 0
        }

        Item {
            id: content

            // 不再跟随 sizer 重新排版：页面始终按最终尺寸布局，横向与
            // 展开中的面板中心对齐，由 sizer 裁切逐步显露。此前外壳变形
            // 的每一帧都在重排三列页面，中间列与时钟卡会经历负尺寸布局
            x: (sizer.width - controller.pageWidth) / 2 + 16
            y: 16
            width: Math.max(0, controller.pageWidth - 32)
            height: Math.max(0, Theme.dashboardHeight - 24)

            // 外壳接近展开完成才淡入内容（打开 100ms / 收起 40ms）；
            // 透明度不阻止输入，enabled 需独立门控
            readonly property bool contentVisible:
                controller.open && root.p >= 0.99

            opacity: contentVisible ? 1 : 0
            enabled: controller.open
                && root.p >= 0.999 && opacity >= 0.99
            Behavior on opacity {
                NumberAnimation {
                    duration: controller.reducedMotion
                        || root.animDuration <= 0
                        ? 0 : (controller.open ? 100 : 40)
                    easing.type: Easing.OutCubic
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
