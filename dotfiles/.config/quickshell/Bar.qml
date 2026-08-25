import "." as Core
import QtQuick
import "components"
import "config" as Config

Rectangle {
    id: bar

    // 兼容 shell.qml 的既有注入接口；顶栏视觉使用下方固定 instrument tokens。
    property var root: null
    property real unit: 13.6
    property color zenInk: "#141414"
    property color zenMist: "#2a2a2a"
    property color zenStone: "#1f1f1f"
    property color zenAsh: "#3a3a3a"
    property color zenSmoke: "#5a5a5a"
    property color zenCloud: "#8a8a8a"
    property color zenSnow: "#cacaca"
    property color zenPure: "#f0f0f0"
    property color zenAccent: "#5a9a8a"
    property color zenDanger: "#9a5555"
    property var panelWindow: null
    property int trayDirectIconLimit: 3
    property int notificationHistoryCount: 0
    property var notificationSourceCounts: []
    property bool trayPanelExpanded: false
    property bool rightPanelOpen: false
    property real rightPanelProgress: rightPanelOpen ? 1 : 0
    property real rightPanelBaseWidth: naturalRightContourWidth
    property real rightPanelTargetWidth: openRightContourWidth
    readonly property int trayPowerGap: Config.BarTuning.trayPowerGap
    readonly property int leftIslandOffsetX: Config.BarTuning.leftIslandOffsetX
    readonly property int centerIslandOffsetX: Config.BarTuning.centerIslandOffsetX
    readonly property int rightIslandOffsetX: Config.BarTuning.rightIslandOffsetX
    readonly property int islandHeight: Config.BarTuning.islandHeight
    readonly property int barHeight: Config.BarTuning.barHeight
    readonly property int topBorderWidth: Config.BarTuning.barTopBorderWidth
    readonly property int notchRadius: Config.BarTuning.barNotchRadius
    readonly property int exclusionGap: Config.BarTuning.barExclusionGap
    readonly property int islandContentTop: Config.BarTuning.islandContentTop
    readonly property int islandGap: Config.BarTuning.islandGap
    readonly property int minimumSupportedWidth: Config.BarTuning.minimumSupportedWidth
    readonly property int layoutMode: width >= Config.BarTuning.fullTrayMinWidth ? 0 : (width >= Config.BarTuning.traySurfaceMinWidth ? 2 : (width >= Config.BarTuning.compactMinWidth ? 3 : 4))
    readonly property int responsiveTrayIconLimit: trayDirectIconLimit
    readonly property int currentVolume: root && root.volumePercent !== undefined ? root.volumePercent : 0
    readonly property var currentScreen: panelWindow ? panelWindow.screen : null
    // Swiss industrial Bar 的稳定视觉 token；与 Matugen 动态面板强调色隔离。
    readonly property color panelSurface: Config.Theme.surface
    readonly property color secondarySurface: Config.Theme.surface
    readonly property color utilitySurface: Config.Theme.surface
    readonly property color hoverSurface: Config.Theme.surfaceContainer
    readonly property color panelBorder: Config.Theme.outline
    readonly property color panelHighlight: Config.Theme.outlineVariant
    readonly property color textPrimary: Config.Theme.textPrimary
    readonly property color textSecondary: Config.Theme.textSecondary
    readonly property color textDim: Config.Theme.textMuted
    readonly property color linePrimary: Config.Theme.outline
    readonly property color lineSecondary: Config.Theme.outlineVariant
    readonly property color instrumentAccent: Config.Theme.accent
    readonly property color occupiedTone: Config.Theme.textMuted
    readonly property color inactiveTone: Config.Theme.surfaceContainer
    readonly property string monoFont: "JetBrains Mono"
    readonly property real contextRight: contextIslandItem.x + contextIslandItem.width
    readonly property real contextWidth: contextIslandItem.width
    readonly property real clockLeft: clockIslandItem.x
    readonly property real clockRight: clockLeft + clockIslandItem.width
    readonly property real clockWidth: clockIslandItem.width
    readonly property real systemLeft: systemIslandItem.x
    readonly property real systemWidth: systemIslandItem.width
    readonly property real naturalRightContourWidth: width - systemLeft
    // 在极窄屏幕上以中央岛的排斥区为硬上限，避免两个轮廓相交。
    readonly property real availableRightNeckWidth: Math.max(
        naturalRightContourWidth,
        width - clockRight - exclusionGap
    )
    readonly property real openRightContourWidth: Math.max(
        naturalRightContourWidth,
        Math.min(Config.BarTuning.rightPanelNeckWidth,
                 availableRightNeckWidth)
    )
    readonly property real normalizedRightPanelProgress: Math.max(
        0, Math.min(1, rightPanelProgress)
    )
    readonly property real animationTargetRightWidth: Math.max(
        naturalRightContourWidth,
        Math.min(openRightContourWidth, rightPanelTargetWidth)
    )
    readonly property real animationBaseRightWidth:
        rightPanelOpen || normalizedRightPanelProgress > 0.001
        ? Math.max(1, Math.min(animationTargetRightWidth,
                              rightPanelBaseWidth))
        : naturalRightContourWidth
    readonly property real animatedRightContourWidth:
        Math.round(animationBaseRightWidth
        + (animationTargetRightWidth - animationBaseRightWidth)
            * normalizedRightPanelProgress)
    readonly property real centeredClockLeft: (width - clockWidth) / 2 + centerIslandOffsetX
    readonly property real minimumClockLeft: contextRight + exclusionGap
    readonly property real maximumClockLeft: systemLeft - exclusionGap - clockWidth
    readonly property real resolvedClockLeft: Math.max(minimumClockLeft,
                                                       Math.min(centeredClockLeft, maximumClockLeft))
    readonly property real contextContourLeft: 0
    readonly property real contextContourRight: contextRight + notchRadius
    readonly property real clockContourLeft: clockLeft - notchRadius
    readonly property real clockContourRight: clockRight + notchRadius
    readonly property real systemContourLeft:
        width - animatedRightContourWidth - notchRadius
    readonly property real systemContourRight: width
    readonly property int metricsWidth: systemIslandItem.metricsWidth
    readonly property real trayWidth: systemIslandItem.trayWidth
    readonly property int systemSpacing: systemIslandItem.spacing
    readonly property int utilitySpacing: systemIslandItem.utilityGap
    readonly property bool trayVisible: systemIslandItem.showTray
    readonly property bool metricDetailsVisible: systemIslandItem.showSegments
    readonly property int actualTrayIconLimit: systemIslandItem.trayIconLimit
    property alias centerIsland: clockIslandItem

    signal systemClicked()
    signal trayPanelToggleRequested(real panelWidth)
    signal trayPanelResizeRequested(real panelWidth)
    signal trayPanelCloseRequested()

    implicitHeight: barHeight
    color: "transparent"

    BarContour {
        id: barContour

        anchors.fill: parent
        leftWidth: bar.contextRight
        centerWidth: clockIslandItem.width
        centerOffset: bar.clockLeft - (bar.width - clockIslandItem.width) / 2
        rightWidth: bar.animatedRightContourWidth
        notchHeight: bar.barHeight
        notchRadius: bar.notchRadius
        topBorderWidth: bar.topBorderWidth
        surfaceColor: bar.panelSurface
    }

    ContextIsland {
        id: contextIslandItem

        x: bar.leftIslandOffsetX
        y: bar.islandContentTop
        width: implicitWidth
        height: bar.islandHeight
        contextState: Core.TopBarState
        niriState: Core.Niri
        screen: bar.currentScreen
        responsiveLevel: bar.layoutMode
        surfaceColor: "transparent"
        borderColor: "transparent"
        highlightColor: "transparent"
        textColor: bar.textPrimary
        textSoft: bar.textSecondary
        textDim: bar.textDim
        lineColor: bar.linePrimary
        accentColor: bar.instrumentAccent
        occupiedColor: bar.occupiedTone
        emptyColor: bar.inactiveTone
        monoFont: bar.monoFont
    }

    ClockIsland {
        id: clockIslandItem

        x: bar.resolvedClockLeft
        y: bar.islandContentTop
        width: implicitWidth
        height: bar.islandHeight
        responsiveLevel: bar.layoutMode
        reducedMotion: Core.TopBarState.reducedMotion
        surfaceColor: "transparent"
        hoverColor: bar.hoverSurface
        borderColor: "transparent"
        highlightColor: "transparent"
        textColor: bar.textPrimary
        textSoft: bar.textSecondary
        textDim: bar.textDim
        lineColor: bar.linePrimary
        accentColor: bar.instrumentAccent
        monoFont: bar.monoFont
    }

    SystemIsland {
        id: systemIslandItem

        anchors.right: parent.right
        anchors.rightMargin: -bar.rightIslandOffsetX
        y: bar.islandContentTop
        width: contentWidth
        height: bar.islandHeight
        metricsState: Core.TopBarState
        panelWindow: bar.panelWindow
        responsiveLevel: bar.layoutMode
        volumePercent: bar.currentVolume
        requestedTrayIconLimit: bar.responsiveTrayIconLimit
        notificationHistoryCount: bar.notificationHistoryCount
        notificationSourceCounts: bar.notificationSourceCounts
        trayPanelExpanded: bar.trayPanelExpanded
        integratedSurface: true
        metricsSurface: bar.secondarySurface
        utilitySurface: bar.utilitySurface
        hoverSurface: bar.hoverSurface
        borderColor: bar.panelBorder
        highlightColor: bar.panelHighlight
        textSoft: bar.textSecondary
        textDim: bar.textDim
        lineSoft: bar.lineSecondary
        accentColor: bar.instrumentAccent
        segmentOn: bar.occupiedTone
        segmentOff: bar.inactiveTone
        dangerColor: bar.zenDanger
        monoFont: bar.monoFont
        onToggleSystemPanel: bar.systemClicked()
        onToggleTrayPanel: (panelWidth) => {
            return bar.trayPanelToggleRequested(panelWidth);
        }
        onResizeTrayPanel: (panelWidth) => {
            return bar.trayPanelResizeRequested(panelWidth);
        }
        onCloseTrayPanel: bar.trayPanelCloseRequested()
    }
}
