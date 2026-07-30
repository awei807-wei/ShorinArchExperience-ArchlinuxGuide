import "../config" as Config
import QtQuick

Rectangle {
    id: clockIsland

    property int responsiveLevel: 0
    property bool reducedMotion: false
    property color surfaceColor: Qt.rgba(10 / 255, 12 / 255, 13 / 255, 0.94)
    property color hoverColor: Qt.rgba(18 / 255, 20 / 255, 21 / 255, 0.95)
    property color borderColor: Qt.rgba(1, 1, 1, 0.085)
    property color highlightColor: Qt.rgba(1, 1, 1, 0.045)
    property color textColor: "#e7e9ea"
    property color textSoft: "#a7abad"
    property color textDim: "#6d7376"
    property color lineColor: Qt.rgba(1, 1, 1, 0.1)
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
    readonly property int timeColumnWidth: ultraCompact ? Config.BarTuning.clockUltraTimeColumnWidth : (compact ? Config.BarTuning.clockCompactTimeColumnWidth : Config.BarTuning.clockTimeColumnWidth)
    readonly property int dateColumnWidth: ultraCompact ? Config.BarTuning.clockUltraDateColumnWidth : (compact ? Config.BarTuning.clockCompactDateColumnWidth : Config.BarTuning.clockDateColumnWidth)

    function shake() {
        if (!reducedMotion)
            shakeAnimation.restart();

    }

    function updateClock() {
        const now = new Date();
        const weekdays = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"];
        const months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
        timeText = String(now.getHours()).padStart(2, "0") + ":" + String(now.getMinutes()).padStart(2, "0");
        dateText = now.getFullYear() + "." + String(now.getMonth() + 1).padStart(2, "0") + "." + String(now.getDate()).padStart(2, "0");
        weekdayText = weekdays[now.getDay()] + " · " + months[now.getMonth()];
    }

    implicitWidth: ultraCompact ? Config.BarTuning.clockUltraWidth : (compact ? Config.BarTuning.clockCompactWidth : Config.BarTuning.clockWidth)
    implicitHeight: Config.BarTuning.islandHeight
    color: hovered ? hoverColor : surfaceColor
    border.color: borderColor
    border.width: Config.BarTuning.islandBorderWidth
    radius: Config.BarTuning.islandRadius
    clip: true
    Accessible.role: Accessible.StaticText
    Accessible.name: "Clock"

    SequentialAnimation {
        id: shakeAnimation

        NumberAnimation {
            target: clockIsland
            property: "shakeOffset"
            to: 2
            duration: 45
        }

        NumberAnimation {
            target: clockIsland
            property: "shakeOffset"
            to: -2
            duration: 45
        }

        NumberAnimation {
            target: clockIsland
            property: "shakeOffset"
            to: 0
            duration: 45
        }

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
        height: Config.BarTuning.islandTopHighlightHeight
        color: clockIsland.highlightColor
    }

    Row {
        id: clockContent

        anchors.centerIn: parent

        Item {
            width: clockIsland.timeColumnWidth
            height: clockIsland.height

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: clockIsland.timeText
                color: clockIsland.textColor
                font.family: clockIsland.monoFont
                font.pixelSize: Config.BarTuning.clockTimeFontSize
                font.weight: Font.DemiBold
                font.letterSpacing: Config.BarTuning.clockTimeLetterSpacing
            }

        }

        Rectangle {
            width: 1
            height: Config.BarTuning.clockDividerHeight
            anchors.verticalCenter: parent.verticalCenter
            color: clockIsland.lineColor
        }

        Item {
            width: clockIsland.dateColumnWidth
            height: clockIsland.height

            Column {
                anchors.left: parent.left
                anchors.leftMargin: clockIsland.compact ? Config.BarTuning.clockCompactDateInset : Config.BarTuning.clockDateInset
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - anchors.leftMargin
                spacing: Config.BarTuning.clockMetaSpacing

                Text {
                    width: parent.width
                    text: clockIsland.dateText
                    elide: Text.ElideRight
                    color: clockIsland.textSoft
                    font.family: clockIsland.monoFont
                    font.pixelSize: Config.BarTuning.clockDateFontSize
                    font.letterSpacing: 0.385
                }

                Text {
                    width: parent.width
                    text: clockIsland.showVolume ? "VOL · " + String(clockIsland.volume).padStart(2, "0") + "%" : clockIsland.weekdayText
                    elide: Text.ElideRight
                    color: clockIsland.showVolume ? clockIsland.accentColor : clockIsland.textDim
                    font.family: clockIsland.monoFont
                    font.pixelSize: Config.BarTuning.clockWeekdayFontSize
                    font.letterSpacing: clockIsland.showVolume ? 0.5 : 0.75

                    Behavior on color {
                        enabled: !clockIsland.reducedMotion

                        ColorAnimation {
                            duration: 150
                        }

                    }

                }

            }

        }

    }

    MouseArea {
        id: hoverArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    transform: Translate {
        x: clockIsland.shakeOffset
    }

    Behavior on color {
        enabled: !clockIsland.reducedMotion

        ColorAnimation {
            duration: 180
        }

    }

}
