// 为每块屏幕承载顶栏下方的通知历史窗口。
import QtQuick
import Quickshell
import Quickshell.Wayland

Variants {
    id: panelHost

    property var root: null
    property var store: null
    property bool open: false
    property real panelWidth: (root?.baseUnit ?? 13.6) * 18
    property real rightMargin: 0

    signal closeRequested()

    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: historyWindow
            required property var modelData
            screen: modelData
            visible: panelHost.open && panelHost.store?.historyCount > 0
            exclusiveZone: -1
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            margins.top: panelHost.root.barMarginTop
                + panelHost.root.islandHeight
                + panelHost.root.baseUnit * 0.18
            color: "transparent"
            WlrLayershell.keyboardFocus: visible
                ? WlrKeyboardFocus.OnDemand
                : WlrKeyboardFocus.None

            MouseArea {
                z: 0
                anchors.fill: parent
                onClicked: panelHost.closeRequested()
            }

            TrayNotificationPanel {
                z: 1
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.rightMargin: panelHost.rightMargin
                store: panelHost.store
                open: historyWindow.visible
                unit: panelHost.root.baseUnit
                panelWidth: panelHost.panelWidth
                zenInk: panelHost.root.zenInk
                zenStone: panelHost.root.zenStone
                zenMist: panelHost.root.zenMist
                zenAsh: panelHost.root.zenAsh
                zenSmoke: panelHost.root.zenSmoke
                zenCloud: panelHost.root.zenCloud
                zenSnow: panelHost.root.zenSnow
                zenAccent: panelHost.root.zenAccent
                zenDanger: panelHost.root.zenDanger
                onCloseRequested: panelHost.closeRequested()
            }
        }
    }
}
