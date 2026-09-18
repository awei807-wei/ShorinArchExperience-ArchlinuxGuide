import "../config" as Config
import "RightPanelGeometry.js" as Geometry
import QtQuick
import Quickshell
import Quickshell.Wayland

// 面板外部点击捕获层：中岛或右侧面板任一打开时，映射一个全屏透明窗口，
// 点击面板以外的区域即关闭全部面板，Esc 同样关闭。输入区域扣除两个面板
// 的最终矩形，面板自身的点击仍落到常驻的面板窗口。两个面板窗口不再各自
// 携带全屏关闭层，也不再随开合映射/卸载。
Scope {
    id: host

    required property var shellRoot
    required property var centerController
    required property var rightController

    readonly property real barBottom:
        shellRoot.barMarginTop + shellRoot.barHeight
    readonly property real rightPanelTop: Math.max(
        shellRoot.barMarginTop,
        barBottom - Config.BarTuning.rightPanelFlare
    )

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: catcher

                required property var modelData

                readonly property bool centerOpen:
                    host.centerController.open
                    && host.centerController.isScreenActive(modelData)
                readonly property bool rightOpen:
                    host.rightController.open
                    && host.rightController.isScreenActive(modelData)
                readonly property real centerPanelLeft:
                    host.centerController.centerCenterX > 0
                    ? host.centerController.centerCenterX
                        - host.centerController.pageWidth / 2
                    : (modelData.width - host.centerController.pageWidth) / 2
                readonly property int rightPanelWidth:
                    Geometry.panelWidth(modelData.width, Config.BarTuning)
                readonly property int rightPanelBodyHeight: Math.max(
                    0,
                    Geometry.panelContentHeight(
                        modelData.height, host.rightPanelTop,
                        host.barBottom, Config.BarTuning)
                        - Config.BarTuning.rightPanelFlare
                )

                function closeAll() {
                    host.centerController.close()
                    host.rightController.close()
                }

                screen: modelData
                visible: centerOpen || rightOpen
                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }
                // Bar 条带不在捕获范围内：打开期间点击岛屿仍走各自的开关逻辑
                margins.top: host.barBottom
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: catcher.visible
                    ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

                mask: Region {
                    x: 0
                    y: 0
                    width: catcher.width
                    height: catcher.height

                    Region {
                        intersection: Intersection.Subtract
                        x: catcher.centerPanelLeft
                        y: 0
                        width: catcher.centerOpen
                            ? host.centerController.pageWidth : 0
                        height: host.centerController.pageHeight
                    }

                    Region {
                        intersection: Intersection.Subtract
                        x: catcher.modelData.width
                            - host.shellRoot.barMarginSide
                            - catcher.rightPanelWidth
                        y: 0
                        width: catcher.rightOpen ? catcher.rightPanelWidth : 0
                        height: catcher.rightPanelBodyHeight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    focus: true
                    onClicked: catcher.closeAll()
                    Keys.onEscapePressed: catcher.closeAll()
                }
            }
        }
    }
}
