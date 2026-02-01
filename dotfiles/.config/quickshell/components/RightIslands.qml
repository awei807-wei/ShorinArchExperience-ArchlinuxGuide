import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Row {
    id: rightIslands
    property real unit: parent?.unit ?? 13.6
    property color zenInk: parent?.zenInk ?? "#141414"
    property color zenMist: parent?.zenMist ?? "#2a2a2a"
    property color zenStone: parent?.zenStone ?? "#1f1f1f"
    property color zenAsh: parent?.zenAsh ?? "#3a3a3a"
    property color zenSmoke: parent?.zenSmoke ?? "#5a5a5a"
    property color zenCloud: parent?.zenCloud ?? "#8a8a8a"
    property color zenSnow: parent?.zenSnow ?? "#cacaca"
    property color zenAccent: "#5a9a8a"
    property var panelWindow: null

    // Cava 频谱数据
    property string cavaData: "▁▁▁▁▁▁▁▁"
    property bool cavaActive: false

    spacing: unit * 0.6
    height: parent?.height ?? unit * 2
    signal toggleSystemPanel()

    property int cpuPercent: 0
    property int memPercent: 0
    property int _memTotal: 0
    property int _memAvail: 0
    property int _prevCpuIdle: 0
    property int _prevCpuTotal: 0
    property int batPercent: 100

    Component.onCompleted: {
        cpuProc.running = true
        memProc.running = true
        batProc.running = true
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            cpuProc.running = true
            memProc.running = true
            batProc.running = true
        }
    }

    Process {
        id: cavaProc
        command: ["/home/shiyi/.config/eww/scripts/cava.sh"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    let json = JSON.parse(data)
                    rightIslands.cavaData = json.bars || "▁▁▁▁▁▁▁▁"
                    rightIslands.cavaActive = json.active || false
                } catch(e) {}
            }
        }
    }
    Process {
        id: cpuProc
        command: ["cat", "/proc/stat"]
        stdout: SplitParser { onRead: data => {
            if (data.startsWith("cpu ")) {
                let parts = data.split(/\s+/)
                let user = parseInt(parts[1]) || 0
                let nice = parseInt(parts[2]) || 0
                let system = parseInt(parts[3]) || 0
                let idle = parseInt(parts[4]) || 0
                let iowait = parseInt(parts[5]) || 0
                let irq = parseInt(parts[6]) || 0
                let softirq = parseInt(parts[7]) || 0
                let total = user + nice + system + idle + iowait + irq + softirq
                let idleAll = idle + iowait
                let diffIdle = idleAll - rightIslands._prevCpuIdle
                let diffTotal = total - rightIslands._prevCpuTotal
                rightIslands._prevCpuIdle = idleAll
                rightIslands._prevCpuTotal = total
                if (diffTotal > 0) {
                    rightIslands.cpuPercent = Math.round((1 - diffIdle / diffTotal) * 100)
                }
            }
        }}
    }

    Process {
        id: memProc
        command: ["cat", "/proc/meminfo"]
        stdout: SplitParser { onRead: data => {
            if (data.startsWith("MemTotal:")) {
                rightIslands._memTotal = parseInt(data.split(/\s+/)[1]) || 0
            } else if (data.startsWith("MemAvailable:")) {
                rightIslands._memAvail = parseInt(data.split(/\s+/)[1]) || 0
                if (rightIslands._memTotal > 0) {
                    rightIslands.memPercent = Math.round((rightIslands._memTotal - rightIslands._memAvail) * 100 / rightIslands._memTotal)
                }
            }
        }}
    }

    Process {
        id: batProc
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100"]
        stdout: SplitParser { onRead: data => rightIslands.batPercent = parseInt(data) || 100 }
    }

    Rectangle {
        id: systemIsland
        width: systemRow.implicitWidth + unit * 2
        height: parent.height
        color: zenInk
        border.color: zenMist
        border.width: 1
        radius: 2

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: systemIsland.color = zenStone
            onExited: systemIsland.color = zenInk
            onClicked: {
                console.log("[RightIslands] systemIsland clicked")
                rightIslands.toggleSystemPanel()
            }
        }

        Row {
            id: systemRow
            anchors.centerIn: parent
            spacing: unit * 0.5

            Row {
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: rightIslands.cavaData.length
                    Rectangle {
                        width: 2; anchors.verticalCenter: parent.verticalCenter
                        height: unit * (0.1 + 0.7 * "▁▂▃▄▅▆▇█".indexOf(rightIslands.cavaData[index] || "▁") / 7)
                        color: zenAccent
                        Behavior on height { NumberAnimation { duration: 80 } }
                    }
                }
            }
            Rectangle { width: 1; height: unit * 0.7; color: zenMist; anchors.verticalCenter: parent.verticalCenter }

            Row {
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter
                Text { text: "MEM"; font.pixelSize: unit * 0.32; color: zenCloud }
                Text { text: memPercent + "%"; font.pixelSize: unit * 0.38; color: zenSnow }
            }

            Rectangle { width: 1; height: unit * 0.7; color: zenMist; anchors.verticalCenter: parent.verticalCenter }

            Row {
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter
                Text { text: "CPU"; font.pixelSize: unit * 0.32; color: zenCloud }
                Text { text: cpuPercent + "%"; font.pixelSize: unit * 0.38; color: zenSnow }
            }

            Rectangle { width: 1; height: unit * 0.7; color: zenMist; anchors.verticalCenter: parent.verticalCenter }

            Row {
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    width: 16; height: 7
                    color: "transparent"
                    border.color: zenAsh
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        x: 1; y: 1
                        width: Math.max((parent.width - 2) * batPercent / 100, 0)
                        height: parent.height - 2
                        color: zenCloud
                    }
                }
                Text { text: batPercent + "%"; font.pixelSize: unit * 0.38; color: zenSnow }
            }
        }
    }

    Rectangle {
        id: trayIsland
        width: Math.max(trayRow.implicitWidth + unit * 1.2, unit * 2.5)
        height: parent.height
        color: zenInk
        border.color: zenMist
        border.width: 1
        radius: 2

        Row {
            id: trayRow
            anchors.centerIn: parent
            spacing: unit * 0.4

            Repeater {
                model: SystemTray.items
                Item {
                    id: trayItemContainer
                    width: unit * 1.2
                    height: unit * 1.2
                    Rectangle {
                        id: trayItemBg
                        anchors.fill: parent
                        color: "transparent"
                        radius: 2
                        Image {
                            anchors.centerIn: parent
                            width: unit * 0.9
                            height: unit * 0.9
                            source: modelData.icon
                            sourceSize.width: unit * 0.9
                            sourceSize.height: unit * 0.9
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onEntered: trayItemBg.color = zenStone
                        onExited: trayItemBg.color = "transparent"
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                if (modelData.hasMenu) menuAnchor.open()
                            } else {
                                modelData.activate()
                            }
                        }
                    }
                    QsMenuAnchor {
                        id: menuAnchor
                        menu: modelData.menu
                        anchor.window: rightIslands.panelWindow
                        anchor.item: trayItemBg
                    }
                }
            }
            Text {
                visible: SystemTray.items.count === 0
                text: "···"
                font.pixelSize: unit * 0.4
                color: zenAsh
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Rectangle {
        id: powerIsland
        width: unit * 1.8
        height: parent.height
        color: zenInk
        border.color: zenMist
        border.width: 1
        radius: 2
        Text {
            anchors.centerIn: parent
            text: "⏻"
            font.pixelSize: unit * 0.5
            color: zenSmoke
        }
        Process {
            id: wlogoutProc
            command: ["wlogout"]
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: { powerIsland.color = zenStone; powerIsland.border.color = zenSmoke }
            onExited: { powerIsland.color = zenInk; powerIsland.border.color = zenMist }
            onClicked: wlogoutProc.running = true
        }
    }
}
