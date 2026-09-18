import QtQuick
import Quickshell
import Quickshell.Wayland
import "../vendor/brain"
import "../vendor/brain/components"
import "../vendor/brain/services/"
import "../vendor/brain/services/center/"
import "../config" as Config

// 中岛子面板内容宿主 — Brain_Shell Dashboard.qml (MIT) 改良移植。
// 面板背景（共享外轮廓）由 bar 窗口绘制；本窗口只承载内容，并且常驻
// 映射：关闭态输入区域为空、内容透明，开合只动裁剪与透明度，不再随
// 开合映射/卸载窗口或用 visible 卸载内容。此前每次打开都在内容显露
// 那一帧重建整棵内容树，实测产生 40–58ms 的单帧停顿。
// 点击面板外关闭由 PanelOutsideClickCatcher 承担。
PanelWindow {
    id: root

    required property var controller
    required property var modelData
    screen: modelData

    readonly property bool panelActiveOnScreen:
        controller.isScreenActive(modelData)
    // 本屏消费的开合进度：非触发屏幕保持收拢
    readonly property real p: panelActiveOnScreen
        ? Math.max(0, Math.min(1, controller.centerPanelProgress)) : 0
    // 打开或收回途中（含收尾隐藏延迟）都视为在视野内，输入区域随之开启
    readonly property bool inView:
        controller.windowVisible && panelActiveOnScreen
    // 内容显露进度：由外壳进度经 smoothstep 派生，和裁剪同步显露，
    // 不再等外壳落地后再单独淡入
    readonly property real contentT: smoothstep(
        Config.BarTuning.centerPanelContentStartProgress,
        Config.BarTuning.centerPanelContentEndProgress, p)
    readonly property int pageFadeDuration: controller.reducedMotion
        ? 0 : Config.BarTuning.centerPanelPageFadeDuration
    // 启动预热：先以 0.001 的下限透明度渲染一轮内容（低于 0.001 的子树会
    // 被场景图整体跳过），提前建好着色器管线、图层与字形纹理；否则热重载
    // 或登录后第一次打开的内容首帧实测 70–90ms
    property bool prewarming: Config.BarTuning.panelPrewarmDuration > 0

    Timer {
        interval: Math.max(1, Config.BarTuning.panelPrewarmDuration)
        running: root.prewarming
        onTriggered: root.prewarming = false
    }

    function smoothstep(a, b, value) {
        const t = Math.max(0, Math.min(1, (value - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    // 频谱采集只在面板完全展开并停在 Home 页时运行：动画期间内容尚在
    // 显露，提前拉起只会把进程启动和 16ms 缓动计时器压进动画帧。
    // 单一消费方汇总注入，后续多个消费者时应改为计数/汇总模式
    Binding {
        target: CavaService
        property: "active"
        value: controller.open
            && controller.centerPanelProgress >= 0.999
            && controller.page === "home"
            && !controller.reducedMotion
    }

    color: "transparent"
    visible: true

    // 常驻窗口只覆盖面板可能出现的水平条带：顶边伸入 bar 底边 2 逻辑
    // 像素吸收双窗口接缝，高度为面板最大下探
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 2 + Theme.dashboardHeight
    margins.top: Math.max(0, Config.BarTuning.barMarginTop
        + Config.BarTuning.barHeight - 2)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus:
        controller.open && panelActiveOnScreen
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // 关闭态输入区域为空，点击穿透；打开态只覆盖面板矩形，
    // 并让出与 bar 重叠的 2 逻辑像素
    mask: Region {
        x: sizer.x
        y: 2
        width: root.inView ? sizer.width : 0
        height: root.inView ? Math.max(0, sizer.height - 2) : 0
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
        // bar 侧轮廓底边逐帧同值
        width: controller.centerWidth
            + (controller.pageWidth - controller.centerWidth) * root.p
        height: 2 + Theme.dashboardHeight * root.p

        // 吞掉面板内部点击，避免穿透到桌面；外部点击由捕获层处理
        MouseArea {
            anchors.fill: parent
            enabled: root.inView
            onClicked: {}
        }

        Item {
            id: content

            // 页面始终按最终尺寸布局，横向与展开中的面板中心对齐，由 sizer
            // 裁切逐步显露；显露过程中轻微上抬，透明度随 contentT 变化
            x: (sizer.width - controller.pageWidth) / 2 + 16
            y: 16 - Config.BarTuning.centerPanelContentLift * (1 - root.contentT)
            width: Math.max(0, controller.pageWidth - 32)
            height: Math.max(0, Theme.dashboardHeight - 24)
            opacity: root.prewarming
                ? Math.max(0.001, root.contentT) : root.contentT
            // 透明度不阻止输入，enabled 需独立门控
            enabled: controller.open && root.p >= 0.999

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

                    // Home 是默认页，常驻渲染：打开面板时不能再付整页首帧成本
                    Item {
                        anchors.fill: parent
                        opacity: controller.page === "home" ? 1 : 0
                        enabled: controller.page === "home"
                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.pageFadeDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                        DashHome { anchors.fill: parent }
                    }

                    // 次要页面：交叉淡入，淡出结束后才卸载。采集门控由宿主
                    // 注入：面板打开期间即采样（切到本页时读数已就绪），
                    // 收起后停止，不再因停留在本页而在关闭态继续轮询
                    Item {
                        anchors.fill: parent
                        opacity: controller.page === "stats" ? 1 : 0
                        visible: opacity > 0.001
                        enabled: controller.page === "stats"
                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.pageFadeDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                        DashStats {
                            anchors.fill: parent
                            active: visible && controller.open
                                && root.panelActiveOnScreen
                        }
                    }

                    Item {
                        anchors.fill: parent
                        opacity: controller.page === "kanban" ? 1 : 0
                        visible: opacity > 0.001
                        enabled: controller.page === "kanban"
                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.pageFadeDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                        KanbanBoard { anchors.fill: parent }
                    }
                }
            }
        }
    }
}
