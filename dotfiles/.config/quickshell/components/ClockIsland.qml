import "../config" as Config
import QtQuick

Rectangle {
    id: clockIsland

    property int responsiveLevel: 0
    property bool reducedMotion: false
    property color surfaceColor: Config.Theme.surface
    property color hoverColor: Config.Theme.surfaceContainer
    property color borderColor: Config.Theme.outline
    property color highlightColor: Config.Theme.outlineVariant
    property color textColor: Config.Theme.textPrimary
    property color textSoft: Config.Theme.textSecondary
    property color textDim: Config.Theme.textMuted
    property color lineColor: Config.Theme.outline
    property color accentColor: Config.Theme.accent
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
    radius: Config.Theme.radiusMedium
    clip: true
    Accessible.role: Accessible.StaticText
    Accessible.name: "Clock"

    SequentialAnimation {
        id: shakeAnimation

        NumberAnimation {
            target: clockIsland
            property: "shakeOffset"
            to: 2
            duration: Config.Theme.animFast
        }

        NumberAnimation {
            target: clockIsland
            property: "shakeOffset"
            to: -2
            duration: Config.Theme.animFast
        }

        NumberAnimation {
            target: clockIsland
            property: "shakeOffset"
            to: 0
            duration: Config.Theme.animFast
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
        // 水平内缩一个圆角半径，避免直角高亮条戳出圆角轮廓
        anchors.leftMargin: clockIsland.radius
        anchors.rightMargin: clockIsland.radius
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
                    font.pixelSize: Config.Theme.fontTiny
                    font.letterSpacing: 0.385
                }

                Text {
                    width: parent.width
                    text: clockIsland.showVolume ? "VOL · " + String(clockIsland.volume).padStart(2, "0") + "%" : clockIsland.weekdayText
                    elide: Text.ElideRight
                    color: clockIsland.showVolume ? clockIsland.accentColor : clockIsland.textDim
                    font.family: clockIsland.monoFont
                    font.pixelSize: Config.Theme.fontTiny
                    font.letterSpacing: clockIsland.showVolume ? 0.5 : 0.75

                    Behavior on color {
                        enabled: !clockIsland.reducedMotion

                        ColorAnimation {
                            duration: Config.Theme.animFast
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
            duration: Config.Theme.animNormal
        }

    }

}
