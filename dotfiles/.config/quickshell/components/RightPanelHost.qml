import "../config" as Config
import QtQuick
import Quickshell
import Quickshell.Wayland

// 固定的全屏宿主只负责 Wayland 表面、定位和输入。面板实际几何全部
// 在 UnifiedRightPanel 的内部 sizer 中变化，不动画窗口尺寸或锚点。
Scope {
    id: host

    required property var shellRoot
    required property var controller
    required property var store

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

                readonly property int panelWidth: host.clamp(
                    Math.round(modelData.width
                        * Config.BarTuning.rightPanelWidthRatio),
                    Math.min(Config.BarTuning.rightPanelWidthMin,
                             modelData.width),
                    Math.min(Config.BarTuning.rightPanelWidthMax,
                             modelData.width)
                )
                readonly property int availablePanelHeight: Math.max(
                    Config.BarTuning.rightPanelFlare,
                    modelData.height - host.barBottom - 24
                )
                readonly property int controlHeight: Math.min(
                    Config.BarTuning.rightPanelControlHeight,
                    availablePanelHeight
                )
                readonly property int historyMaximumHeight: Math.min(
                    Config.BarTuning.rightPanelHistoryMaxHeight,
                    availablePanelHeight
                )
                readonly property int maximumPanelHeight: Math.max(
                    controlHeight,
                    historyMaximumHeight
                )

                screen: modelData
                visible: host.controller.windowVisible
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
                    ? WlrKeyboardFocus.OnDemand
                    : WlrKeyboardFocus.None
                mask: Region { item: windowInput }

                // 打开期间保留单次外部点击关闭；退场一开始，输入区域立刻
                // 缩回可见 sizer，使固定透明外窗不再吞掉桌面点击。
                Item {
                    id: windowInput

                    x: host.controller.open
                        ? 0
                        : panel.x + panel.inputRegion.x
                    y: host.controller.open
                        ? Config.BarTuning.rightPanelFlare
                        : panel.y + panel.inputRegion.y
                    width: host.controller.open
                        ? panelWindow.width
                        : panel.inputRegion.width
                    height: host.controller.open
                        ? Math.max(0, panelWindow.height
                            - Config.BarTuning.rightPanelFlare)
                        : panel.inputRegion.height
                }

                MouseArea {
                    z: 0
                    anchors.fill: parent
                    anchors.topMargin: Config.BarTuning.rightPanelFlare
                    enabled: host.controller.open
                    onClicked: host.controller.close()
                }

                UnifiedRightPanel {
                    id: panel

                    z: 1
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.rightMargin: host.shellRoot.barMarginSide
                    width: panelWindow.panelWidth
                    height: panelWindow.maximumPanelHeight
                    controlTargetHeight: panelWindow.controlHeight
                    historyMaximumHeight: panelWindow.historyMaximumHeight
                    availablePanelHeight: panelWindow.availablePanelHeight
                    shellRoot: host.shellRoot
                    store: host.store
                    open: host.controller.open
                    page: host.controller.page
                    reducedMotion: host.controller.reducedMotion
                    onCloseRequested: host.controller.close()
                    onPageRequested: targetPage =>
                        host.controller.showPage(targetPage)
                    onCloseAnimationFinished:
                        host.controller.finishClose()
                }
            }
        }
    }
}
