pragma ComponentBehavior: Bound

import QtQuick
import "../config" as Config

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
    readonly property bool compactLayout: width < Config.BarTuning.metricsCompactLayoutThreshold
    readonly property int outerPadding: compactLayout
        ? Config.BarTuning.metricsCompactOuterPadding : Config.BarTuning.metricsOuterPadding
    readonly property int metricFontSize: width < Config.BarTuning.metricsSmallFontThreshold
        ? Config.BarTuning.metricsSmallFontSize : Config.BarTuning.metricsFontSize
    readonly property var metricData: [
        { "label": "NET", "value": networkValue, "level": networkLevel, "accent": true },
        { "label": "MEM", "value": formatPercent(memoryPercent), "level": percentLevel(memoryPercent), "accent": false },
        { "label": "CPU", "value": formatPercent(cpuPercent), "level": percentLevel(cpuPercent), "accent": false },
        { "label": "VOL", "value": formatPercent(volumePercent), "level": percentLevel(volumePercent), "accent": false }
    ]

    signal clicked()

    implicitWidth: Config.BarTuning.metricsWidth
    implicitHeight: Config.BarTuning.islandHeight
    color: hovered ? hoverColor : surfaceColor
    border.color: borderColor
    border.width: Config.BarTuning.islandBorderWidth
    radius: Config.BarTuning.islandRadius
    clip: true

    function formatPercent(value) {
        return String(Math.max(0, Math.min(100, Math.round(value)))).padStart(2, "0") + "%"
    }

    function percentLevel(value) {
        return Math.max(0, Math.min(Config.BarTuning.metricsSegmentCount,
            Math.ceil(value / (100 / Config.BarTuning.metricsSegmentCount))))
    }

    Behavior on color {
        enabled: !metrics.reducedMotion
        ColorAnimation { duration: 180 }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Config.BarTuning.islandTopHighlightHeight
        color: metrics.highlightColor
    }

    Rectangle {
        x: Config.BarTuning.metricsAccentX
        y: metrics.border.width
        width: Config.BarTuning.metricsAccentWidth
        height: Config.BarTuning.islandTopHighlightHeight
        color: metrics.accentColor
        opacity: Config.BarTuning.metricsAccentOpacity
        z: 4
    }

    Spectrum {
        anchors.fill: parent
        anchors.topMargin: Config.BarTuning.spectrumTopInset
        anchors.leftMargin: metrics.outerPadding
        anchors.rightMargin: metrics.outerPadding
        anchors.bottomMargin: Config.BarTuning.spectrumBottomInset
        bars: metrics.spectrumBars
        active: metrics.spectrumActive
        reducedMotion: metrics.reducedMotion
        z: 0
    }

    Row {
        id: metricRow
        anchors.fill: parent
        anchors.leftMargin: metrics.outerPadding
        anchors.rightMargin: metrics.outerPadding
        z: 2

        Repeater {
            model: metrics.metricData

            Item {
                id: metricCell

                required property int index
                required property var modelData
                readonly property int horizontalPadding: metrics.compactLayout
                    ? (metrics.showSegments
                        ? Config.BarTuning.metricsCompactCellPadding
                        : Config.BarTuning.metricsCompactCellPaddingWithoutSegments)
                    : (metrics.showSegments
                        ? Config.BarTuning.metricsCellPadding
                        : Config.BarTuning.metricsCellPaddingWithoutSegments)

                width: metricRow.width / 4
                height: metricRow.height

                Rectangle {
                    visible: metricCell.index > 0
                    x: 0
                    y: Config.BarTuning.metricsDividerY
                    width: 1
                    height: Config.BarTuning.metricsDividerHeight
                    color: metrics.lineSoft
                }

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: metricCell.horizontalPadding
                    anchors.rightMargin: metricCell.horizontalPadding

                    Text {
                        anchors.left: parent.left
                        width: parent.width * Config.BarTuning.metricsLabelWidthRatio
                        y: metrics.showSegments
                            ? (metrics.compactLayout
                                ? Config.BarTuning.metricsCompactTextY
                                : Config.BarTuning.metricsTextY)
                            : (metrics.compactLayout
                                ? Config.BarTuning.metricsCompactTextYWithoutSegments
                                : Config.BarTuning.metricsTextYWithoutSegments)
                        text: metricCell.modelData.label
                        elide: Text.ElideRight
                        color: metrics.textDim
                        font.family: metrics.monoFont
                        font.pixelSize: metrics.metricFontSize
                        font.letterSpacing: metrics.compactLayout ? 0.38 : 0.5
                    }

                    Text {
                        anchors.right: parent.right
                        width: parent.width * Config.BarTuning.metricsValueWidthRatio
                        y: metrics.showSegments
                            ? (metrics.compactLayout
                                ? Config.BarTuning.metricsCompactTextY
                                : Config.BarTuning.metricsTextY)
                            : (metrics.compactLayout
                                ? Config.BarTuning.metricsCompactTextYWithoutSegments
                                : Config.BarTuning.metricsTextYWithoutSegments)
                        text: metricCell.modelData.value
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignRight
                        color: metrics.textSoft
                        font.family: metrics.monoFont
                        font.pixelSize: metrics.metricFontSize
                        font.weight: Font.Medium
                        font.letterSpacing: 0.05
                    }

                    Row {
                        id: segmentRow

                        visible: metrics.showSegments
                        x: 0
                        y: Config.BarTuning.metricsSegmentY
                        width: parent.width
                        height: Config.BarTuning.metricsSegmentHeight
                        spacing: Config.BarTuning.metricsSegmentGap

                        Repeater {
                            model: Config.BarTuning.metricsSegmentCount

                            Rectangle {
                                required property int index
                                width: (segmentRow.width
                                    - (Config.BarTuning.metricsSegmentCount - 1)
                                        * Config.BarTuning.metricsSegmentGap)
                                    / Config.BarTuning.metricsSegmentCount
                                height: Config.BarTuning.metricsSegmentHeight
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
