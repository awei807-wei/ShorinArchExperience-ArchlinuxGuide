import QtQuick
import Quickshell
import Quickshell.Wayland
import "../vendor/brain"
import "../vendor/brain/components"
import "../vendor/brain/services/"
import "../vendor/brain/services/center/"
import "../config" as Config

// 中岛子面板宿主 — Brain_Shell Dashboard.qml (MIT) 改良移植：
// 共享外轮廓（岛底 → 面板底，含底角 15 → 17 随动）已全部由 bar 窗口
// 绘制（单 surface，动态接缝消失），本窗口只承载两件无动画几何的事：
// ① sizer 覆盖面板区域的吞点击层；② 固定最终尺寸的内容层（接近
// 展开完成才淡入）；外加全屏关闭层（点击面板外即关闭）。
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

    // 模拟频谱等装饰更新的门控：面板展开 + Home 页 + 非减少动画。
    // 单一消费方汇总注入，后续多个消费者时应改为计数/汇总模式
    Binding {
        target: CavaService
        property: "active"
        value: controller.open
            && controller.page === "home"
            && !controller.reducedMotion
    }

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

        // 共享外轮廓：宽度在中岛宽 ↔ 页宽之间插值（与 Bar.centerPanelCWidth
        // 同式）；高度 = 2px 重叠 + dashboardHeight × 进度，使面板底边与
        // bar 侧轮廓底边（barHeight + dashboardHeight × 进度）逐帧同值；
        // 底角半径随共享轮廓从岛底 15 过渡到面板底 17，高度不足以容纳
        // 底角半径随共享轮廓插值（15 → 17），低高度大半径由 bar 侧
        // Shape 的虚拟顶边处理
        width: controller.centerWidth
            + (controller.pageWidth - controller.centerWidth)
              * Math.max(0, Math.min(1, controller.centerPanelProgress))
        height: 2 + Theme.dashboardHeight
            * Math.max(0, Math.min(1, controller.centerPanelProgress))

        // 吞掉面板内部点击，避免穿透到关闭层。
        // 面板背景已由 bar 窗口的共享外轮廓绘制（单 surface），本窗口
        // 只承载内容与关闭层，无动画几何，跨窗口无同步需求
        MouseArea {
            anchors.fill: parent
            onClicked: {}
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

            // 外壳接近展开完成才淡入内容（打开 60ms / 收起 40ms）；
            // 透明度不阻止输入，enabled 需独立门控。
            // 0.98 为布局挤压问题解决后的放宽阈值，勿再回退到保守值
            readonly property bool contentVisible:
                controller.open && root.p >= 0.98

            opacity: contentVisible ? 1 : 0
            enabled: controller.open
                && root.p >= 0.999 && opacity >= 0.99
            Behavior on opacity {
                NumberAnimation {
                    duration: controller.reducedMotion
                        || root.animDuration <= 0
                        ? 0 : (controller.open ? 60 : 40)
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
