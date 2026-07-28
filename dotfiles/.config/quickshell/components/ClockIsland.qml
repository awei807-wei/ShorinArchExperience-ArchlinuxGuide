import QtQuick

Rectangle {
    id: clockIsland

    property int responsiveLevel: 0
    property bool showWeather: true
    property string weatherText: "--°C"
    property bool reducedMotion: false
    property color surfaceColor: Qt.rgba(10 / 255, 12 / 255, 13 / 255, 0.94)
    property color hoverColor: Qt.rgba(18 / 255, 20 / 255, 21 / 255, 0.95)
    property color borderColor: Qt.rgba(1, 1, 1, 0.085)
    property color highlightColor: Qt.rgba(1, 1, 1, 0.045)
    property color textColor: "#e7e9ea"
    property color textSoft: "#a7abad"
    property color textDim: "#6d7376"
    property color lineColor: Qt.rgba(1, 1, 1, 0.10)
    property color accentColor: "#8fb3c5"
    property string monoFont: "JetBrains Mono"

    property string timeText: "00:00"
    property string dateText: "2026.07.28"
    property string weekdayText: "TUESDAY"
    property bool showVolume: false
    property int volume: 0
    property real shakeOffset: 0

    readonly property bool hovered: hoverArea.containsMouse
    readonly property bool ultraCompact: responsiveLevel >= 4
    readonly property bool compact: responsiveLevel >= 3

    signal togglePanel()

    implicitWidth: showWeather ? 300 : (ultraCompact ? 170 : (compact ? 190 : 229))
    implicitHeight: 38
    color: hovered ? hoverColor : surfaceColor
    border.color: borderColor
    border.width: 1
    radius: 3
    clip: true
    transform: Translate { x: clockIsland.shakeOffset }
    Accessible.role: Accessible.Button
    Accessible.name: "Clock and system controls"

    function shake() {
        if (!reducedMotion)
            shakeAnimation.restart()
    }

    function updateClock() {
        const now = new Date()
        const weekdays = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
        const months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

        timeText = String(now.getHours()).padStart(2, "0") + ":"
            + String(now.getMinutes()).padStart(2, "0")
        dateText = now.getFullYear() + "."
            + String(now.getMonth() + 1).padStart(2, "0") + "."
            + String(now.getDate()).padStart(2, "0")
        weekdayText = weekdays[now.getDay()] + " · " + months[now.getMonth()]
    }

    Behavior on color {
        enabled: !clockIsland.reducedMotion
        ColorAnimation { duration: 180 }
    }

    SequentialAnimation {
        id: shakeAnimation
        NumberAnimation { target: clockIsland; property: "shakeOffset"; to: 2; duration: 45 }
        NumberAnimation { target: clockIsland; property: "shakeOffset"; to: -2; duration: 45 }
        NumberAnimation { target: clockIsland; property: "shakeOffset"; to: 0; duration: 45 }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clockIsland.updateClock()
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: clockIsland.highlightColor
    }

    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: clockIsland.border.width
        anchors.horizontalCenter: parent.horizontalCenter
        width: clockIsland.showVolume ? Math.max(24, Math.round(clockIsland.volume * 0.42)) : 24
        height: 1
        color: clockIsland.accentColor
        opacity: 0.9
        z: 3

        Behavior on width {
            enabled: !clockIsland.reducedMotion
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
    }

    Row {
        id: clockContent
        anchors.centerIn: parent

        Item {
            width: clockIsland.compact ? 62 : 78
            height: clockIsland.height

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: clockIsland.timeText
                color: clockIsland.textColor
                font.family: clockIsland.monoFont
                font.pixelSize: 15
                font.weight: Font.DemiBold
                font.letterSpacing: -0.525
            }
        }

        Rectangle {
            width: 1
            height: 18
            anchors.verticalCenter: parent.verticalCenter
            color: clockIsland.lineColor
        }

        Item {
            width: clockIsland.ultraCompact ? 83 : (clockIsland.compact ? 102 : 112)
            height: clockIsland.height

            Column {
                anchors.left: parent.left
                anchors.leftMargin: clockIsland.compact ? 9 : 13
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    text: clockIsland.dateText
                    color: clockIsland.textSoft
                    font.family: clockIsland.monoFont
                    font.pixelSize: 7
                    font.letterSpacing: 0.385
                }

                Text {
                    text: clockIsland.showVolume
                        ? "VOL · " + String(clockIsland.volume).padStart(2, "0") + "%"
                        : clockIsland.weekdayText
                    color: clockIsland.showVolume ? clockIsland.accentColor : clockIsland.textDim
                    font.family: clockIsland.monoFont
                    font.pixelSize: 6
                    font.letterSpacing: clockIsland.showVolume ? 0.5 : 0.75

                    Behavior on color {
                        enabled: !clockIsland.reducedMotion
                        ColorAnimation { duration: 150 }
                    }
                }
            }
        }

        Rectangle {
            visible: clockIsland.showWeather
            width: visible ? 1 : 0
            height: 18
            anchors.verticalCenter: parent.verticalCenter
            color: clockIsland.lineColor
        }

        Item {
            visible: clockIsland.showWeather
            width: visible ? 70 : 0
            height: clockIsland.height

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: clockIsland.weatherText
                color: clockIsland.textSoft
                font.family: clockIsland.monoFont
                font.pixelSize: 7
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                width: parent.width - 4
            }
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: clockIsland.togglePanel()
    }
}
