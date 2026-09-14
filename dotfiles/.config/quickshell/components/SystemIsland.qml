import "../config" as Config
import QtQuick

Row {
    id: systemIsland

    property var metricsState: null
    property var panelWindow: null
    property int responsiveLevel: 0
    property int requestedTrayIconLimit: 3
    property int notificationHistoryCount: 0
    property var notificationSourceCounts: []
    property bool trayPanelExpanded: false
    property bool integratedSurface: false
    property color metricsSurface: Config.Theme.surface
    property color utilitySurface: Config.Theme.surface
    property color hoverSurface: Config.Theme.surfaceContainer
    property color borderColor: Config.Theme.outline
    property color highlightColor: Config.Theme.outlineVariant
    property color textSoft: Config.Theme.textSecondary
    property color textDim: Config.Theme.textMuted
    property color lineSoft: Config.Theme.outlineVariant
    property color accentColor: Config.Theme.accent
    property color dangerColor: Config.Theme.danger
    property string monoFont: "JetBrains Mono"
    readonly property bool reducedMotion: metricsState ? metricsState.reducedMotion : false
    // 右岛内容预算独立于完整面板：关闭态固定 240px，展开态的
    // 304px 宽度只是一段稳定颈部，不会被业务内容反向撑宽。
    readonly property bool showTray: true
    readonly property int metricsWidth: Config.BarTuning.rightIslandMetricsWidth
    readonly property int trayIconLimit: Math.min(
        requestedTrayIconLimit,
        Config.BarTuning.rightIslandDirectIconLimit
    )
    readonly property real trayWidth: trayItem.width
    readonly property int utilityGap: Config.BarTuning.trayPowerGap
    readonly property real contentWidth: metricsWidth + spacing
        + Config.BarTuning.powerIslandWidth
        + (showTray ? trayWidth + utilityGap : 0)

    signal toggleSystemPanel()
    signal toggleTrayPanel(real panelWidth)
    signal resizeTrayPanel(real panelWidth)
    signal closeTrayPanel()

    width: contentWidth
    spacing: Config.BarTuning.metricsUtilityGap

    Metrics {
        id: metricsItem

        width: systemIsland.metricsWidth
        height: Config.BarTuning.islandHeight
        cpuPercent: systemIsland.metricsState ? systemIsland.metricsState.cpuPercent : 0
        memoryPercent: systemIsland.metricsState ? systemIsland.metricsState.memPercent : 0
        batteryPercent: systemIsland.metricsState
            ? systemIsland.metricsState.batteryPercent : 100
        batteryAvailable: systemIsland.metricsState
            ? systemIsland.metricsState.batteryAvailable : false
        reducedMotion: systemIsland.reducedMotion
        surfaceColor: systemIsland.integratedSurface ? "transparent" : systemIsland.metricsSurface
        hoverColor: systemIsland.hoverSurface
        borderColor: systemIsland.integratedSurface ? "transparent" : systemIsland.borderColor
        highlightColor: systemIsland.integratedSurface ? "transparent" : systemIsland.highlightColor
        accentColor: systemIsland.accentColor
        onClicked: systemIsland.toggleSystemPanel()
    }

    Row {
        id: utilityCluster

        height: Config.BarTuning.islandHeight
        spacing: systemIsland.utilityGap

        TrayIsland {
            id: trayItem

            visible: systemIsland.showTray
            width: visible ? implicitWidth : 0
            height: Config.BarTuning.islandHeight
            unit: Config.BarTuning.trayUnit
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
            notificationSourceCounts: systemIsland.notificationSourceCounts
            expanded: systemIsland.trayPanelExpanded
            reducedMotion: systemIsland.reducedMotion
            highlightColor: systemIsland.highlightColor
            integratedSurface: systemIsland.integratedSurface
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

            width: Config.BarTuning.powerIslandWidth
            height: Config.BarTuning.islandHeight
            reducedMotion: systemIsland.reducedMotion
            surfaceColor: systemIsland.integratedSurface ? "transparent" : systemIsland.utilitySurface
            hoverColor: Config.Theme.surfaceContainer
            borderColor: systemIsland.integratedSurface ? "transparent" : systemIsland.borderColor
            highlightColor: systemIsland.integratedSurface ? "transparent" : systemIsland.highlightColor
            iconColor: systemIsland.textDim
            iconHoverColor: systemIsland.textSoft
        }

    }

}
