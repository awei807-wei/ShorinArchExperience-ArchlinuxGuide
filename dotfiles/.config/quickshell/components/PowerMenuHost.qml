import "../config" as Config
import QtQuick
import Quickshell
import Quickshell.Wayland

// 右侧电源菜单宿主：
// 贴合屏幕右边缘垂直居中常驻映射，关闭态区域穿透，开合只动揭示视口与形状深度。
Scope {
    id: host

    required property var shellRoot
    required property var controller

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: window

                required property var modelData

                readonly property bool panelActiveOnScreen:
                    host.controller.isScreenActive(modelData)
                readonly property real p: panelActiveOnScreen
                    ? host.controller.powerMenuProgress : 0
                readonly property bool inView:
                    host.controller.windowVisible && panelActiveOnScreen

                readonly property int flareSize: 18
                readonly property int totalWidth: host.controller.menuWidth + flareSize
                readonly property int totalHeight: host.controller.menuHeight + flareSize * 2

                screen: modelData
                visible: true
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"

                anchors {
                    right: true
                    top: true
                }
                margins.right: 0
                margins.top: Math.round((modelData.height - totalHeight) / 2)
                implicitWidth: totalWidth
                implicitHeight: totalHeight

                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: host.controller.open && panelActiveOnScreen
                    ? WlrKeyboardFocus.OnDemand
                    : WlrKeyboardFocus.None

                // 输入区域只覆盖展开的凹槽主体
                mask: Region {
                    x: Math.round(window.totalWidth - (host.controller.menuWidth * window.p + window.flareSize))
                    y: 0
                    width: window.inView ? Math.round(host.controller.menuWidth * window.p + window.flareSize) : 0
                    height: window.inView ? window.totalHeight : 0
                }

                // 连体外壳
                RightSideNotchShape {
                    id: notchShape
                    anchors.fill: parent
                    depth: host.controller.menuWidth * window.p
                    bodyHeight: host.controller.menuHeight
                    flare: window.flareSize
                    radius: 16
                    surfaceColor: Config.Theme.surface
                }

                // 揭示内容视口
                Item {
                    id: contentHost
                    anchors {
                        right: parent.right
                        top: parent.top
                        bottom: parent.bottom
                    }
                    anchors.topMargin: window.flareSize + 8
                    anchors.bottomMargin: window.flareSize + 8
                    anchors.rightMargin: 12
                    width: host.controller.menuWidth - 24

                    // 进度大于 0.2 时平滑淡入，轻微左移
                    readonly property real contentProgress: Math.max(0, Math.min(1, (window.p - 0.2) / 0.8))

                    opacity: window.inView ? contentProgress : 0
                    visible: opacity > 0.001
                    transform: Translate {
                        x: 12 * (1 - contentHost.contentProgress)
                    }

                    RightPowerMenuContent {
                        id: menuContent
                        anchors.fill: parent
                        onCloseRequested: host.controller.close()
                    }

                    Connections {
                        target: host.controller
                        function onOpenChanged() {
                            if (host.controller.open && window.panelActiveOnScreen) {
                                Qt.callLater(() => menuContent.forceActiveFocus())
                            }
                        }
                    }
                }
            }
        }
    }
}