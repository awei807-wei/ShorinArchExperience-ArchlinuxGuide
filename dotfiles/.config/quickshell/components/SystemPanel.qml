import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: systemRoot
    property real unit: 24
    property color zenInk: "#141414"
    property color zenMist: "#2a2a2a"
    property color zenStone: "#1f1f1f"
    property color zenAsh: "#3a3a3a"
    property color zenSmoke: "#5a5a5a"
    property color zenCloud: "#8a8a8a"
    property color zenSnow: "#cacaca"
    property color zenAccent: "#5a9a8a"

    property int cpuPercent: 0
    property real memUsed: 0
    property int batPercent: 100

    implicitWidth: unit * 18
    implicitHeight: sysContent.height + unit * 1.0

    function refreshData() {
        cpuProc.running = true
        memProc.running = true
        batProc.running = true
    }

    Component.onCompleted: refreshData()

    Process { id: cpuProc; command: ["sh", "-c", "grep 'cpu ' /proc/stat | awk '{u=($2+$4)*100/($2+$4+$5)} END {printf \"%.0f\", u}'"]; stdout: SplitParser { onRead: data => systemRoot.cpuPercent = parseInt(data) || 0 } }
    Process { id: memProc; command: ["sh", "-c", "free -g | awk '/Mem:/ {printf \"%.1f\", $3}'"]; stdout: SplitParser { onRead: data => systemRoot.memUsed = parseFloat(data) || 0 } }
    Process { id: batProc; command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100"]; stdout: SplitParser { onRead: data => systemRoot.batPercent = parseInt(data) || 100 } }

    Rectangle {
        id: sysBg
        anchors.fill: parent
        color: zenInk; border.color: zenMist; border.width: 1; radius: 2

        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: false
            onClicked: mouse => mouse.accepted = true
        }

        Column {
            id: sysContent
            anchors.top: parent.top; anchors.topMargin: unit * 0.5
            anchors.left: parent.left; anchors.right: parent.right
            spacing: unit * 0.5

            Text { x: unit * 0.8; text: "SYSTEM STATUS"; font.pixelSize: unit * 0.28; font.letterSpacing: 3; color: zenAsh }

            Column {
                x: unit * 0.8; spacing: unit * 0.2
                Text { text: "CPU LOAD"; font.pixelSize: unit * 0.35; color: zenSmoke }
                Rectangle {
                    width: unit * 16.4; height: 4; color: zenMist
                    Rectangle { width: parent.width * systemRoot.cpuPercent / 100; height: 4; color: zenAccent }
                }
                Text { text: systemRoot.cpuPercent + "% / 16 Cores"; font.pixelSize: unit * 0.3; color: zenCloud }
            }

            Column {
                x: unit * 0.8; spacing: unit * 0.2
                Text { text: "MEMORY USAGE"; font.pixelSize: unit * 0.35; color: zenSmoke }
                Rectangle {
                    width: unit * 16.4; height: 4; color: zenMist
                    Rectangle { width: parent.width * (systemRoot.memUsed / 32); height: 4; color: zenCloud }
                }
                Text { text: systemRoot.memUsed + "GB / 32GB Total"; font.pixelSize: unit * 0.3; color: zenCloud }
            }

            Column {
                x: unit * 0.8; spacing: unit * 0.2
                Text { text: "POWER RESOURCE"; font.pixelSize: unit * 0.35; color: zenSmoke }
                Row {
                    spacing: unit * 0.4
                    Rectangle {
                        width: unit * 2; height: unit * 0.8; color: "transparent"; border.color: zenAsh; border.width: 1
                        Rectangle { x: 1; y: 1; width: (parent.width-2) * systemRoot.batPercent / 100; height: parent.height-2; color: zenAccent }
                    }
                    Text { text: systemRoot.batPercent + "% Healthy"; font.pixelSize: unit * 0.35; color: zenCloud }
                }
            }
            Item { width: 1; height: unit * 0.2 }
        }
    }
}