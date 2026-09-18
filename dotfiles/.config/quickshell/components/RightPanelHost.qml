import "../config" as Config
import "RightPanelGeometry.js" as Geometry
import QtQuick
import Quickshell
import Quickshell.Wayland

// 每屏固定宿主只负责 Wayland 表面、定位和输入。窗口常驻映射，只覆盖
// 面板的最终几何；关闭态输入区域为空，打开后输入区域跟随 reveal viewport
// 的可见主体。面板外壳按最终几何绘制，viewport 与 Bar 消费同一份状态。
// 外部点击关闭由 PanelOutsideClickCatcher 承担。此前窗口随开合映射/卸载，
// 每次打开都重建整棵场景图，实测首次位移被推迟到点击后 66–122ms。
Scope {
    id: host

    required property var shellRoot
    required property var controller
    required property var store
    property var trayItems: []
    property int trayModelRevision: 0

    readonly property real barBottom:
        shellRoot.barMarginTop + shellRoot.barHeight
    readonly property real panelTop: Math.max(
        shellRoot.barMarginTop,
        barBottom - Config.BarTuning.rightPanelFlare
    )

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: panelWindow

                required property var modelData

                readonly property bool panelActiveOnScreen:
                    host.controller.isScreenActive(modelData)
                // 打开或收回途中（含收尾隐藏延迟）都视为在视野内
                readonly property bool inView:
                    host.controller.windowVisible && panelActiveOnScreen
                readonly property int panelWidth:
                    Geometry.panelWidth(modelData.width, Config.BarTuning)
                readonly property int panelContentHeight:
                    Geometry.panelContentHeight(
                        modelData.height, host.panelTop,
                        host.barBottom, Config.BarTuning)

                screen: modelData
                visible: true
                exclusionMode: ExclusionMode.Ignore
                anchors {
                    top: true
                    right: true
                }
                margins.top: host.panelTop
                margins.right: host.shellRoot.barMarginSide
                implicitWidth: panelWidth
                implicitHeight: panelContentHeight
                color: "transparent"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: host.controller.open
                    && panelActiveOnScreen
                    ? WlrKeyboardFocus.OnDemand
                    : WlrKeyboardFocus.None

                // 输入区域只覆盖 reveal viewport 的可见主体，并避开由 Bar
                // 持有的重叠 flare；关闭态为空区域，点击穿透到桌面。
                mask: Region {
                    x: panel.inputRegion.x
                    y: panel.inputRegion.y
                    width: panelWindow.inView ? panel.inputRegion.width : 0
                    height: panelWindow.inView ? panel.inputRegion.height : 0
                }

                UnifiedRightPanel {
                    id: panel

                    anchors.fill: parent
                    shellRoot: host.shellRoot
                    store: host.store
                    menuWindow: panelWindow
                    trayItems: host.trayItems
                    trayModelRevision: host.trayModelRevision
                    open: host.controller.open
                        && panelWindow.panelActiveOnScreen
                    page: host.controller.page
                    shellProgress: panelWindow.panelActiveOnScreen
                        ? host.controller.progress : 0
                    baseRightWidth: host.controller.baseRightWidth
                    targetRightWidth: host.controller.targetRightWidth
                    reducedMotion: host.controller.reducedMotion
                    onCloseRequested: host.controller.close()
                    onPageRequested: targetPage =>
                        host.controller.showPage(targetPage)
                }
            }
        }
    }
}
