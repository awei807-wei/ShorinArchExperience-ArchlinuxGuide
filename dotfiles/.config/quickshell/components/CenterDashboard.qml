import QtQuick
import Quickshell
import Quickshell.Wayland
import "../vendor/brain"
import "../vendor/brain/components"
import "../vendor/brain/services/"
import "../vendor/brain/services/center/"
import "../config" as Config

// 中岛子面板宿主 — Brain_Shell Dashboard.qml (MIT) 改良移植：
// sizer 为 clip 视口，宽/高与 bar 轮廓消费控制器的同一份
// centerPanelProgress，并遵循同一份共享外轮廓：底边随进度从岛底
// （barHeight）下移到面板底（barHeight + dashboardHeight），底角
// 半径随动（15 → 17）；Bar 与面板各自绘制轮廓落在自己窗口内的部分，
// 收拢末段由 CenterPanelShape 虚拟顶边绘制大圆角的可见下段；
// CenterPanelShape 为平顶矩形（无凹角耳朵），窗口顶边与 bar 底边
// 2px 同色重叠吸收接缝；内容固定最终尺寸、接近展开完成才淡入。
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

    // 面板底角半径随共享轮廓：岛底 15 → 面板底 17
    readonly property real panelBottomRadius:
        Theme.notchRadius + (Theme.cornerRadius - Theme.notchRadius) * root.p

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
        // 完整圆弧时由 CenterPanelShape 的虚拟顶边绘制圆弧下段
        width: controller.centerWidth
            + (controller.pageWidth - controller.centerWidth)
              * Math.max(0, Math.min(1, controller.centerPanelProgress))
        height: 2 + Theme.dashboardHeight
            * Math.max(0, Math.min(1, controller.centerPanelProgress))

        // 吞掉面板内部点击，避免穿透到关闭层
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // 平顶矩形：无凹角耳朵。底角半径随共享轮廓从岛底 15 过渡到
        // 面板底 17；高度不足以容纳完整圆弧时由虚拟顶边绘制圆弧下段。
        // Shape 后端：GPU 几何，替代 Canvas 的每帧软件栅格化 + 纹理上传
        CenterPanelShape {
            anchors.fill: parent
            fillColor: Theme.background
            radius: root.panelBottomRadius
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
