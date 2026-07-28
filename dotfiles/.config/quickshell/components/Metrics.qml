pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: metrics

    property string networkValue: "--"
    property int networkLevel: 0
    property int memoryPercent: 0
    property int cpuPercent: 0
    property int volumePercent: 0
    property string spectrumBars: ""
    property bool spectrumActive: false
    property bool showSegments: true
    property bool reducedMotion: false
    property color surfaceColor: Qt.rgba(10 / 255, 12 / 255, 13 / 255, 0.88)
    property color hoverColor: Qt.rgba(18 / 255, 20 / 255, 21 / 255, 0.91)
    property color borderColor: Qt.rgba(1, 1, 1, 0.085)
    property color highlightColor: Qt.rgba(1, 1, 1, 0.045)
    property color textSoft: "#a7abad"
    property color textDim: "#6d7376"
    property color lineSoft: Qt.rgba(1, 1, 1, 0.055)
    property color accentColor: "#8fb3c5"
    property color segmentOn: "#747b7f"
    property color segmentOff: "#3c4143"
    property string monoFont: "JetBrains Mono"

    readonly property bool hovered: pointerArea.containsMouse
    readonly property var metricData: [
        { "label": "NET", "value": networkValue, "level": networkLevel, "accent": true },
        { "label": "MEM", "value": formatPercent(memoryPercent), "level": percentLevel(memoryPercent), "accent": false },
        { "label": "CPU", "value": formatPercent(cpuPercent), "level": percentLevel(cpuPercent), "accent": false },
        { "label": "VOL", "value": formatPercent(volumePercent), "level": percentLevel(volumePercent), "accent": false }
    ]

    signal clicked()

    implicitWidth: 338
    implicitHeight: 38
    color: hovered ? hoverColor : surfaceColor
    border.color: borderColor
    border.width: 1
    radius: 3
    clip: true

    function formatPercent(value) {
        return String(Math.max(0, Math.min(100, Math.round(value)))).padStart(2, "0") + "%"
    }

    function percentLevel(value) {
        return Math.max(0, Math.min(8, Math.ceil(value / 12.5)))
    }

    Behavior on color {
        enabled: !metrics.reducedMotion
        ColorAnimation { duration: 180 }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: metrics.highlightColor
    }

    Rectangle {
        x: 12
        y: 0
        width: 20
        height: 1
        color: metrics.accentColor
        opacity: 0.9
        z: 4
    }

    Spectrum {
        anchors.fill: parent
        anchors.topMargin: 7
        anchors.leftMargin: 9
        anchors.rightMargin: 9
        anchors.bottomMargin: 4
        bars: metrics.spectrumBars
        active: metrics.spectrumActive
        reducedMotion: metrics.reducedMotion
        z: 0
    }

    Row {
        id: metricRow
        anchors.fill: parent
        anchors.leftMargin: 9
        anchors.rightMargin: 9
        z: 2

        Repeater {
            model: metrics.metricData

            Item {
                id: metricCell

                required property int index
                required property var modelData
                readonly property int horizontalPadding: metrics.showSegments ? 9 : 5

                width: metricRow.width / 4
                height: metricRow.height

                Rectangle {
                    visible: metricCell.index > 0
                    x: 0
                    y: 10
                    width: 1
                    height: 17
                    color: metrics.lineSoft
                }

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: metricCell.horizontalPadding
                    anchors.rightMargin: metricCell.horizontalPadding

                    Text {
                        anchors.left: parent.left
                        y: metrics.showSegments ? 9 : 15
                        text: metricCell.modelData.label
                        color: metrics.textDim
                        font.family: metrics.monoFont
                        font.pixelSize: 6
                        font.letterSpacing: 0.72
                    }

                    Text {
                        anchors.right: parent.right
                        y: metrics.showSegments ? 9 : 15
                        text: metricCell.modelData.value
                        color: metrics.textSoft
                        font.family: metrics.monoFont
                        font.pixelSize: 6
                        font.letterSpacing: 0.12
                    }

                    Row {
                        id: segmentRow

                        visible: metrics.showSegments
                        x: 0
                        y: 26
                        width: parent.width
                        height: 2
                        spacing: 2

                        Repeater {
                            model: 8

                            Rectangle {
                                required property int index
                                width: (segmentRow.width - 14) / 8
                                height: 2
                                color: index < metricCell.modelData.level
                                    ? (metricCell.modelData.accent ? metrics.accentColor : metrics.segmentOn)
                                    : metrics.segmentOff

                                Behavior on color {
                                    enabled: !metrics.reducedMotion
                                    ColorAnimation { duration: 140 }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        id: pointerArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: metrics.clicked()
    }
}
