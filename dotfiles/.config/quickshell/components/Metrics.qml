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
    property color surfaceColor: Config.Theme.surface
    property color hoverColor: Config.Theme.surfaceContainer
    property color borderColor: Config.Theme.outline
    property color highlightColor: Config.Theme.outlineVariant
    property color textSoft: Config.Theme.textSecondary
    property color textDim: Config.Theme.textMuted
    property color lineSoft: Config.Theme.outlineVariant
    property color accentColor: Config.Theme.accent
    property color segmentOn: Config.Theme.textMuted
    property color segmentOff: Config.Theme.surfaceContainer
    property string monoFont: "JetBrains Mono"

    readonly property bool hovered: pointerArea.containsMouse
    readonly property bool compactLayout: width < Config.BarTuning.metricsCompactLayoutThreshold
    readonly property bool condensedLayout: width
        < Config.BarTuning.metricsSmallFontThreshold
    readonly property int outerPadding: compactLayout
        ? Config.BarTuning.metricsCompactOuterPadding : Config.BarTuning.metricsOuterPadding
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
    radius: Config.Theme.radiusMedium
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
        ColorAnimation { duration: Config.Theme.animNormal }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        // 水平内缩一个圆角半径，避免直角高亮条戳出圆角轮廓
        anchors.leftMargin: metrics.radius
        anchors.rightMargin: metrics.radius
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
        visible: !metrics.condensedLayout
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
                        font.pixelSize: Config.Theme.fontTiny
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
                        font.pixelSize: Config.Theme.fontTiny
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
                                    ColorAnimation { duration: Config.Theme.animFast }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 130px 右岛模式使用上下两行，而不是在同一行挤压标签和值。
    // 四个状态仍完整保留，最窄单元也不会把文字推到 Tray 区域。
    Row {
        id: condensedMetricRow

        anchors.fill: parent
        anchors.leftMargin: 3
        anchors.rightMargin: 3
        visible: metrics.condensedLayout
        z: 2

        Repeater {
            model: metrics.metricData

            Item {
                id: condensedCell

                required property int index
                required property var modelData

                width: condensedMetricRow.width / 4
                height: condensedMetricRow.height

                Rectangle {
                    visible: condensedCell.index > 0
                    x: 0
                    y: Config.BarTuning.metricsDividerY
                    width: 1
                    height: Config.BarTuning.metricsDividerHeight
                    color: metrics.lineSoft
                }

                Text {
                    x: 2
                    y: 8
                    width: parent.width - 4
                    text: condensedCell.modelData.label
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    color: metrics.textDim
                    font.family: metrics.monoFont
                    font.pixelSize: Config.BarTuning.metricsSmallFontSize
                    font.letterSpacing: 0.2
                }

                Text {
                    x: 1
                    y: 21
                    width: parent.width - 2
                    text: condensedCell.modelData.value
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    color: metrics.textSoft
                    font.family: metrics.monoFont
                    font.pixelSize: Config.BarTuning.metricsSmallFontSize + 1
                    font.weight: Font.Medium
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
