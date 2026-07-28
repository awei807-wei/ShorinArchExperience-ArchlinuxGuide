import QtQuick

Row {
    id: systemIsland

    property var metricsState: null
    property var panelWindow: null
    property int responsiveLevel: 0
    property int volumePercent: 0
    property int requestedTrayIconLimit: 3
    property int notificationHistoryCount: 0
    property bool trayPanelExpanded: false
    property color metricsSurface: Qt.rgba(10 / 255, 12 / 255, 13 / 255, 0.88)
    property color utilitySurface: Qt.rgba(10 / 255, 12 / 255, 13 / 255, 0.86)
    property color hoverSurface: Qt.rgba(18 / 255, 20 / 255, 21 / 255, 0.91)
    property color borderColor: Qt.rgba(1, 1, 1, 0.085)
    property color highlightColor: Qt.rgba(1, 1, 1, 0.045)
    property color textSoft: "#a7abad"
    property color textDim: "#6d7376"
    property color lineSoft: Qt.rgba(1, 1, 1, 0.055)
    property color accentColor: "#8fb3c5"
    property color segmentOn: "#747b7f"
    property color segmentOff: "#3c4143"
    property color dangerColor: "#9a5555"
    property string monoFont: "JetBrains Mono"
    readonly property bool reducedMotion: metricsState ? metricsState.reducedMotion : false
    readonly property bool showTray: responsiveLevel < 3
    readonly property bool showSegments: responsiveLevel < 3
    readonly property int metricsWidth: responsiveLevel <= 2 ? 288 : (responsiveLevel === 3 ? 220 : 176)
    readonly property int trayIconLimit: responsiveLevel <= 1 ? requestedTrayIconLimit : 0
    property int utilityGap: 4

    signal toggleSystemPanel()
    signal toggleTrayPanel(real panelWidth)
    signal resizeTrayPanel(real panelWidth)
    signal closeTrayPanel()

    spacing: 8

    Metrics {
        id: metricsItem

        width: systemIsland.metricsWidth
        height: 38
        networkValue: systemIsland.metricsState ? systemIsland.metricsState.networkRateText : "--"
        networkLevel: systemIsland.metricsState ? systemIsland.metricsState.networkLevel : 0
        memoryPercent: systemIsland.metricsState ? systemIsland.metricsState.memPercent : 0
        cpuPercent: systemIsland.metricsState ? systemIsland.metricsState.cpuPercent : 0
        volumePercent: systemIsland.volumePercent
        spectrumBars: systemIsland.metricsState ? systemIsland.metricsState.cavaData : ""
        spectrumActive: systemIsland.metricsState ? systemIsland.metricsState.cavaActive : false
        showSegments: systemIsland.showSegments
        reducedMotion: systemIsland.reducedMotion
        surfaceColor: systemIsland.metricsSurface
        hoverColor: systemIsland.hoverSurface
        borderColor: systemIsland.borderColor
        highlightColor: systemIsland.highlightColor
        textSoft: systemIsland.textSoft
        textDim: systemIsland.textDim
        lineSoft: systemIsland.lineSoft
        accentColor: systemIsland.accentColor
        segmentOn: systemIsland.segmentOn
        segmentOff: systemIsland.segmentOff
        monoFont: systemIsland.monoFont
        onClicked: systemIsland.toggleSystemPanel()
    }

    Row {
        id: utilityCluster

        height: 38
        spacing: systemIsland.utilityGap

        TrayIsland {
            id: trayItem

            visible: systemIsland.showTray
            width: visible ? (preferredWidth > 0 ? preferredWidth : implicitWidth) : 0
            height: 38
            unit: 8
            preferredWidth: systemIsland.responsiveLevel <= 1 ? 104 : 0
            zenInk: systemIsland.utilitySurface
            zenMist: systemIsland.borderColor
            zenStone: systemIsland.hoverSurface
            zenAsh: systemIsland.lineSoft
            zenCloud: systemIsland.textDim
            zenSnow: systemIsland.textSoft
            zenDanger: systemIsland.dangerColor
            panelWindow: systemIsland.panelWindow
            directIconLimit: systemIsland.trayIconLimit
            notificationCount: systemIsland.notificationHistoryCount
            expanded: systemIsland.trayPanelExpanded
            reducedMotion: systemIsland.reducedMotion
            highlightColor: systemIsland.highlightColor
            monoFont: systemIsland.monoFont
            onToggleRequested: (panelWidth) => {
                return systemIsland.toggleTrayPanel(panelWidth);
            }
            onExpandedWidthChanged: {
                if (systemIsland.trayPanelExpanded)
                    systemIsland.resizeTrayPanel(expandedWidth);

            }
            onCloseRequested: systemIsland.closeTrayPanel()
        }

        Power {
            id: powerItem

            width: 38
            height: 38
            reducedMotion: systemIsland.reducedMotion
            surfaceColor: systemIsland.utilitySurface
            hoverColor: Qt.rgba(1, 1, 1, 0.035)
            borderColor: systemIsland.borderColor
            highlightColor: systemIsland.highlightColor
            iconColor: systemIsland.textDim
            iconHoverColor: systemIsland.textSoft
        }

    }

}
