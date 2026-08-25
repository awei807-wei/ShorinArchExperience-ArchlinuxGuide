import "../config" as Config
import QtQuick
import Quickshell
import Quickshell.Wayland

// 每屏固定宿主只负责 Wayland 表面、定位和输入；只有触发屏幕可见。
// 面板外壳按最终几何绘制，reveal viewport 与 Bar 消费同一份状态。
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

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value))
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: panelWindow

                required property var modelData

                readonly property bool panelActiveOnScreen:
                    host.controller.isScreenActive(modelData)

                readonly property int panelWidth: host.clamp(
                    Math.round(modelData.width
                        * Config.BarTuning.rightPanelWidthRatio),
                    Math.min(Config.BarTuning.rightPanelWidthMin,
                             modelData.width),
                    Math.min(Config.BarTuning.rightPanelWidthMax,
                             modelData.width)
                )
                readonly property int minimumPanelHeight:
                    Config.BarTuning.rightPanelFlare
                    + Config.BarTuning.rightPanelRadius * 2
                    + Config.BarTuning.panelSafeRevealExtra
                readonly property int surfaceHeight: Math.max(
                    0, modelData.height - host.panelTop
                )
                readonly property int availablePanelHeight: Math.max(
                    Math.min(minimumPanelHeight, surfaceHeight),
                    Math.min(surfaceHeight,
                             modelData.height - host.barBottom - 24)
                )
                readonly property int panelContentHeight: Math.min(
                    Config.BarTuning.rightPanelHeight,
                    availablePanelHeight
                )

                screen: modelData
                visible: host.controller.windowVisible
                    && panelActiveOnScreen
                exclusiveZone: -1
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                margins.top: host.panelTop
                color: "transparent"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: host.controller.open
                    && panelActiveOnScreen
                    ? WlrKeyboardFocus.OnDemand
                    : WlrKeyboardFocus.None
                mask: Region { item: windowInput }

                // 打开期间保留单次外部点击关闭；退场一开始，mask 缩回
                // reveal viewport 的可见主体，并避开由 Bar 持有的重叠 flare。
                Item {
                    id: windowInput

                    readonly property bool captureOutside:
                        panelWindow.panelActiveOnScreen
                        && host.controller.open

                    x: captureOutside
                        ? 0
                        : panel.x + panel.inputRegion.x
                    y: captureOutside
                        ? Config.BarTuning.rightPanelFlare
                        : panel.y + panel.inputRegion.y
                    width: captureOutside
                        ? panelWindow.width
                        : panel.inputRegion.width
                    height: captureOutside
                        ? Math.max(0, panelWindow.height
                            - Config.BarTuning.rightPanelFlare)
                        : panel.inputRegion.height
                }

                MouseArea {
                    z: 0
                    anchors.fill: parent
                    anchors.topMargin: Config.BarTuning.rightPanelFlare
                    enabled: windowInput.captureOutside
                    onClicked: host.controller.close()
                }

                UnifiedRightPanel {
                    id: panel

                    z: 1
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.rightMargin: host.shellRoot.barMarginSide
                    width: panelWindow.panelWidth
                    height: panelWindow.panelContentHeight
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
