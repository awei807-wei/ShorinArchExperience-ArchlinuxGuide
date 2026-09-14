import QtQuick
import "../config" as Config

Rectangle {
    id: metrics

    property int cpuPercent: 0
    property int memoryPercent: 0
    property int batteryPercent: 100
    property bool batteryAvailable: false
    property bool reducedMotion: false
    property color surfaceColor: Config.Theme.surface
    property color hoverColor: Config.Theme.surfaceContainer
    property color borderColor: Config.Theme.outline
    property color highlightColor: Config.Theme.outlineVariant
    property color accentColor: Config.Theme.accent
    property color labelColor: "#52525b"
    property color valueColor: "#f4f4f5"
    property color separatorColor: "#27272a"
    property color batteryFallbackColor: "#10b981"
    property string monoFont: Config.BarTuning.metricsFontFamily

    readonly property bool hovered: pointerArea.containsMouse
    readonly property int metricCount: 3
    readonly property real metricCellWidth: (width
        - 2 * Config.BarTuning.metricsHorizontalPadding
        - (metricCount - 1) * Config.BarTuning.metricsSeparatorWidth)
        / metricCount
    readonly property real naturalMetricContentWidth:
        labelSlotMetrics.advanceWidth
        + Config.BarTuning.metricsLabelValueGap
        + valueSlotMetrics.advanceWidth
    readonly property real renderedMetricContentWidth: naturalMetricContentWidth
    readonly property real minimumSeparatorClearance:
        (metricCellWidth - renderedMetricContentWidth) / 2
        + (Config.BarTuning.metricsSeparatorWidth
            - separatorSlotMetrics.advanceWidth) / 2
    readonly property string cpuValue: formatPercent(cpuPercent)
    readonly property string memoryValue: formatPercent(memoryPercent)
    readonly property string batteryValue: batteryAvailable
        ? formatPercent(batteryPercent) : "100%"
    readonly property color batteryValueColor: batteryAvailable
        ? valueColor : batteryFallbackColor

    signal clicked()

    implicitWidth: Config.BarTuning.rightIslandMetricsWidth
    implicitHeight: Config.BarTuning.islandHeight
    color: hovered ? hoverColor : surfaceColor
    border.color: borderColor
    border.width: Config.BarTuning.islandBorderWidth
    radius: Config.Theme.radiusMedium
    clip: true
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: "CPU " + formatPercent(cpuPercent)
        + ", RAM " + formatPercent(memoryPercent)
        + ", BAT " + (batteryAvailable ? formatPercent(batteryPercent) : "100%")

    function formatPercent(value) {
        return String(Math.max(0, Math.min(100, Math.round(value)))) + "%"
    }

    function activate() {
        metrics.clicked()
    }

    Keys.onReturnPressed: metrics.activate()
    Keys.onSpacePressed: metrics.activate()

    Behavior on color {
        enabled: !metrics.reducedMotion
        ColorAnimation { duration: Config.Theme.animNormal }
    }

    TextMetrics {
        id: labelSlotMetrics

        text: "CPU"
        font.family: metrics.monoFont
        font.pixelSize: Config.BarTuning.metricsLabelFontSize
        font.weight: Font.DemiBold
        font.letterSpacing: Config.BarTuning.metricsLabelLetterSpacing
        font.hintingPreference: Font.PreferFullHinting
    }

    TextMetrics {
        id: valueSlotMetrics

        text: "100%"
        font.family: metrics.monoFont
        font.pixelSize: Config.BarTuning.metricsValueFontSize
        font.weight: Font.Bold
        font.hintingPreference: Font.PreferFullHinting
    }

    TextMetrics {
        id: separatorSlotMetrics

        text: "/"
        font.family: metrics.monoFont
        font.pixelSize: Config.BarTuning.metricsSeparatorFontSize
        font.weight: Font.Medium
        font.hintingPreference: Font.PreferFullHinting
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
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

    Row {
        id: metricRow

        x: Config.BarTuning.metricsHorizontalPadding
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 2 * Config.BarTuning.metricsHorizontalPadding
        height: parent.height
        spacing: 0
        z: 2

        TelemetryMetricCell {
            width: metrics.metricCellWidth
            height: metricRow.height
            metricLabel: "CPU"
            metricValue: metrics.cpuValue
            labelColor: metrics.labelColor
            valueColor: metrics.valueColor
            monoFont: metrics.monoFont
            labelSlotWidth: labelSlotMetrics.advanceWidth
            valueSlotWidth: valueSlotMetrics.advanceWidth
            labelValueGap: Config.BarTuning.metricsLabelValueGap
            labelFontSize: Config.BarTuning.metricsLabelFontSize
            valueFontSize: Config.BarTuning.metricsValueFontSize
            labelLetterSpacing: Config.BarTuning.metricsLabelLetterSpacing
        }

        Text {
            width: Config.BarTuning.metricsSeparatorWidth
            height: metricRow.height
            text: "/"
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: metrics.separatorColor
            font.family: metrics.monoFont
            font.pixelSize: Config.BarTuning.metricsSeparatorFontSize
            font.weight: Font.Medium
            font.hintingPreference: Font.PreferFullHinting
            renderType: Text.NativeRendering
        }

        TelemetryMetricCell {
            width: metrics.metricCellWidth
            height: metricRow.height
            metricLabel: "RAM"
            metricValue: metrics.memoryValue
            labelColor: metrics.labelColor
            valueColor: metrics.valueColor
            monoFont: metrics.monoFont
            labelSlotWidth: labelSlotMetrics.advanceWidth
            valueSlotWidth: valueSlotMetrics.advanceWidth
            labelValueGap: Config.BarTuning.metricsLabelValueGap
            labelFontSize: Config.BarTuning.metricsLabelFontSize
            valueFontSize: Config.BarTuning.metricsValueFontSize
            labelLetterSpacing: Config.BarTuning.metricsLabelLetterSpacing
        }

        Text {
            width: Config.BarTuning.metricsSeparatorWidth
            height: metricRow.height
            text: "/"
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: metrics.separatorColor
            font.family: metrics.monoFont
            font.pixelSize: Config.BarTuning.metricsSeparatorFontSize
            font.weight: Font.Medium
            font.hintingPreference: Font.PreferFullHinting
            renderType: Text.NativeRendering
        }

        TelemetryMetricCell {
            width: metrics.metricCellWidth
            height: metricRow.height
            metricLabel: "BAT"
            metricValue: metrics.batteryValue
            labelColor: metrics.labelColor
            valueColor: metrics.batteryValueColor
            monoFont: metrics.monoFont
            labelSlotWidth: labelSlotMetrics.advanceWidth
            valueSlotWidth: valueSlotMetrics.advanceWidth
            labelValueGap: Config.BarTuning.metricsLabelValueGap
            labelFontSize: Config.BarTuning.metricsLabelFontSize
            valueFontSize: Config.BarTuning.metricsValueFontSize
            labelLetterSpacing: Config.BarTuning.metricsLabelLetterSpacing
        }
    }

    MouseArea {
        id: pointerArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            metrics.forceActiveFocus()
            metrics.activate()
        }
    }
}
