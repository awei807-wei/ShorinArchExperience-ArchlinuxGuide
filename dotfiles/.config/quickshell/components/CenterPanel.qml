import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: panelRoot
    property real unit: 24
    property color zenInk: "#141414"
    property color zenMist: "#2a2a2a"
    property color zenStone: "#1f1f1f"
    property color zenAsh: "#3a3a3a"
    property color zenSmoke: "#5a5a5a"
    property color zenCloud: "#8a8a8a"
    property color zenSnow: "#cacaca"

    property string netSSID: "loading..."
    property string btStatus: "OFF"
    property int volumePercent: 70
    property int brightnessPercent: 50
    property string mediaTitle: "No Media"
    property string mediaArtist: "--"
    property bool mediaPlaying: false

    implicitWidth: unit * 22
    implicitHeight: panelContent.height + unit * 1.0

    function refreshData() {
        netProc.running = true
        btProc.running = true
        volProc.running = true
        briProc.running = true
        mediaProc.running = true
    }

    Component.onCompleted: refreshData()

    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2 || echo 'Disconnected'"]
        stdout: SplitParser { onRead: data => panelRoot.netSSID = data.trim() || "Disconnected" }
    }
    Process {
        id: btProc
        command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo 'ON' || echo 'OFF'"]
        stdout: SplitParser { onRead: data => panelRoot.btStatus = data.trim() }
    }
    Process {
        id: volProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*200)}'"]
        stdout: SplitParser { onRead: data => panelRoot.volumePercent = parseInt(data) || 0 }
    }
    Process {
        id: briProc
        command: ["sh", "-c", "brightnessctl -m | cut -d, -f4 | tr -d '%' 2>/dev/null || echo 50"]
        stdout: SplitParser { onRead: data => panelRoot.brightnessPercent = parseInt(data) || 50 }
    }
    Process {
        id: mediaProc
        command: ["sh", "-c", "playerctl metadata --format '{{title}}|||{{artist}}|||{{status}}' 2>/dev/null || echo 'No Media|||--|||Stopped'"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.split("|||")
                panelRoot.mediaTitle = parts[0] || "No Media"
                panelRoot.mediaArtist = parts[1] || "--"
                panelRoot.mediaPlaying = (parts[2] === "Playing")
            }
        }
    }

    Process { id: volSetProc; command: ["echo"] }
    Process { id: briSetProc; command: ["echo"] }
    Process { id: mediaPrevProc; command: ["playerctl", "previous"] }
    Process { id: mediaPlayProc; command: ["playerctl", "play-pause"] }
    Process { id: mediaNextProc; command: ["playerctl", "next"] }
    Process { id: matugenProc; command: ["sh", "-c", "matugen image ~/.config/wallpaper.jpg"] }
    Process { id: reloadProc; command: ["sh", "-c", "pkill quickshell; quickshell &"] }

    Rectangle {
        id: panelBg
        anchors.fill: parent
        color: zenInk; border.color: zenMist; border.width: 1; radius: 2

        // 拦截层
        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: false
            onClicked: mouse => mouse.accepted = true
        }

        Column {
            id: panelContent
            anchors.top: parent.top; anchors.topMargin: unit * 0.5
            anchors.left: parent.left; anchors.right: parent.right
            spacing: unit * 0.15

            Text { x: unit * 0.8; text: "CONNECTIVITY"; font.pixelSize: unit * 0.28; font.letterSpacing: 3; color: zenAsh }
            Row {
                x: unit * 0.8; width: parent.width - unit * 1.6
                Text { text: "NETWORK"; font.pixelSize: unit * 0.35; color: zenSmoke; width: unit * 5 }
                Text { text: panelRoot.netSSID; font.pixelSize: unit * 0.35; color: zenCloud }
            }
            Row {
                x: unit * 0.8; width: parent.width - unit * 1.6
                Text { text: "BLUETOOTH"; font.pixelSize: unit * 0.35; color: zenSmoke; width: unit * 5 }
                Text { text: "archshiyi · " + panelRoot.btStatus; font.pixelSize: unit * 0.35; color: zenCloud }
            }

            Rectangle { x: unit * 0.8; width: parent.width - unit * 1.6; height: 1; color: zenMist }

            Text { x: unit * 0.8; text: "AUDIO / DISPLAY"; font.pixelSize: unit * 0.28; font.letterSpacing: 3; color: zenAsh }
            Row {
                x: unit * 0.8; spacing: unit * 0.5; height: unit * 0.9
                Text { text: "VOL"; font.pixelSize: unit * 0.35; color: zenSmoke; width: unit * 2.5; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    width: unit * 12; height: 3; color: zenMist; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: parent.width * Math.min(panelRoot.volumePercent / 200, 1.0); height: 3; color: zenCloud }
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -10; cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            let pct = Math.round(mouse.x / parent.width * 200)
                            volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (pct / 200).toFixed(2)]
                            volSetProc.running = true
                            panelRoot.volumePercent = pct
                            mouse.accepted = true
                        }
                    }
                }
                Text { text: panelRoot.volumePercent + "%"; font.pixelSize: unit * 0.35; color: zenCloud; width: unit * 3; anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                x: unit * 0.8; spacing: unit * 0.5; height: unit * 0.9
                Text { text: "BRI"; font.pixelSize: unit * 0.35; color: zenSmoke; width: unit * 2.5; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    width: unit * 12; height: 3; color: zenMist; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: parent.width * panelRoot.brightnessPercent / 100; height: 3; color: zenCloud }
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -10; cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            let pct = Math.round(mouse.x / parent.width * 100)
                            briSetProc.command = ["brightnessctl", "set", pct + "%"]
                            briSetProc.running = true
                            panelRoot.brightnessPercent = pct
                            mouse.accepted = true
                        }
                    }
                }
                Text { text: panelRoot.brightnessPercent + "%"; font.pixelSize: unit * 0.35; color: zenCloud; width: unit * 3; anchors.verticalCenter: parent.verticalCenter }
            }

            Rectangle { x: unit * 0.8; width: parent.width - unit * 1.6; height: 1; color: zenMist }

            Text { x: unit * 0.8; text: "NOW PLAYING"; font.pixelSize: unit * 0.28; font.letterSpacing: 3; color: zenAsh }
            Row {
                x: unit * 0.8; width: parent.width - unit * 1.6; height: unit * 1.8; spacing: unit * 0.6
                Column {
                    width: parent.width - unit * 4; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Text { text: panelRoot.mediaTitle; font.pixelSize: unit * 0.38; color: zenSnow; width: parent.width; elide: Text.ElideRight }
                    Text { text: panelRoot.mediaArtist; font.pixelSize: unit * 0.3; color: zenSmoke }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter; spacing: unit * 0.4
                    Repeater {
                        model: ["prev", "play", "next"]
                        Rectangle {
                            width: unit * 1.1; height: unit * 1.1; color: "transparent"; radius: 2
                            Text {
                                anchors.centerIn: parent
                                text: modelData === "prev" ? "⏮" : (modelData === "next" ? "⏭" : (panelRoot.mediaPlaying ? "⏸" : "▶"))
                                font.pixelSize: unit * 0.5; color: zenSmoke
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (modelData === "prev") mediaPrevProc.running = true
                                    else if (modelData === "next") mediaNextProc.running = true
                                    else mediaPlayProc.running = true
                                    mediaProc.running = true
                                    mouse.accepted = true
                                }
                            }
                        }
                    }
                }
            }
            Item { width: 1; height: unit * 0.3 }
        }
    }
}