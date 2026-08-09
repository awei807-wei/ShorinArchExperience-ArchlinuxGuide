import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

// Edge-Integrated Contoured Bar 独立视觉预览。
// 启动：quickshell -p tests/edge-integrated-preview.qml
// 仅使用固定 mock 数据，不连接 Niri、托盘或生产服务。
ShellRoot {
    id: previewRoot

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: previewWindow
                required property var modelData

                screen: modelData
                anchors {
                    top: true
                    left: true
                    right: true
                }
                margins.top: 0
                margins.left: 0
                margins.right: 0
                implicitHeight: 88
                // 覆盖生产 Bar 的保留区，确保预览真正贴合物理屏幕顶边。
                exclusionMode: ExclusionMode.Ignore
                exclusiveZone: 0
                aboveWindows: true
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "edge-integrated-preview"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                color: "transparent"

                EdgeIntegratedBar {
                    anchors.fill: parent
                }
            }
        }
    }
}
