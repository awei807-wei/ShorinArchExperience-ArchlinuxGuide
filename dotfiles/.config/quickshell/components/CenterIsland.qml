import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: centerIsland
    property real unit: parent?.unit ?? 13.6
    property color zenInk: parent?.zenInk ?? "#141414"
    property color zenMist: parent?.zenMist ?? "#2a2a2a"
    property color zenStone: parent?.zenStone ?? "#1f1f1f"
    property color zenAsh: parent?.zenAsh ?? "#3a3a3a"
    property color zenSmoke: parent?.zenSmoke ?? "#5a5a5a"
    property color zenCloud: parent?.zenCloud ?? "#8a8a8a"
    property color zenSnow: parent?.zenSnow ?? "#cacaca"
    property color zenAccent: "#5a9a8a"

    implicitWidth: unit * 10
    implicitHeight: parent?.height ?? unit * 2
    color: zenInk
    border.color: zenMist
    border.width: 1
    radius: 2

    property string timeStr: "00:00"
    property string dateStr: "2026.01.30 THU"
    
    // 动态切换属性
    property bool showVolume: false
    property int volume: 0

    signal togglePanel()

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            let now = new Date()
            centerIsland.timeStr = now.toTimeString().slice(0, 5)
            let weekdays = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
            centerIsland.dateStr = now.getFullYear() + "." +
                String(now.getMonth() + 1).padStart(2, "0") + "." +
                String(now.getDate()).padStart(2, "0") + " " + weekdays[now.getDay()]
        }
    }

    // 时间布局
    Column {
        anchors.centerIn: parent
        spacing: 1
        visible: !centerIsland.showVolume
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: centerIsland.timeStr
            font.pixelSize: unit * 0.5
            font.family: "JetBrains Mono"
            font.letterSpacing: 3
            color: zenSnow
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: centerIsland.dateStr
            font.pixelSize: unit * 0.28
            font.family: "JetBrains Mono"
            font.letterSpacing: 1.5
            color: zenSmoke
        }
    }

    // 音量反馈布局
    Column {
        anchors.centerIn: parent
        width: parent.width * 0.8
        spacing: unit * 0.2
        visible: centerIsland.showVolume
        
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: unit * 0.4
            Text { 
                text: "VOL"
                font.pixelSize: unit * 0.35
                font.family: "JetBrains Mono"
                color: zenCloud
            }
            Text { 
                text: centerIsland.volume + "%"
                font.pixelSize: unit * 0.35
                font.family: "JetBrains Mono"
                color: zenSnow
                font.bold: true
            }
        }
        
        Rectangle {
            width: parent.width
            height: 3
            color: zenMist
            Rectangle {
                width: parent.width * Math.min(centerIsland.volume / 100, 1.0)
                height: parent.height
                color: zenAccent
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: centerIsland.color = zenStone
        onExited: centerIsland.color = zenInk
        onClicked: centerIsland.togglePanel()
    }
}