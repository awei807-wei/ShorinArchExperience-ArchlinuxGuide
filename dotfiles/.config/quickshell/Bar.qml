import QtQuick
import "." as Core
import "components"

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
    property bool trayPanelExpanded: false
    property real leftIslandOffsetX: 0
    property real centerIslandOffsetX: 0
    property real rightIslandOffsetX: 0

    readonly property int islandHeight: 38
    readonly property int islandGap: 8
    readonly property int minimumSupportedWidth: 660
    readonly property int layoutMode: width >= 1344 ? 0
        : (width >= 1273 ? 1 : (width >= 980 ? 2 : (width >= 760 ? 3 : 4)))
    readonly property bool showWeather: layoutMode === 0
    readonly property int responsiveTrayIconLimit: layoutMode <= 1
        ? trayDirectIconLimit : 0
    readonly property int currentVolume: root && root.volumePercent !== undefined
        ? root.volumePercent : 0
    readonly property var currentScreen: panelWindow ? panelWindow.screen : null

    // Swiss industrial Bar 的稳定视觉 token；与 Matugen 动态面板强调色隔离。
    readonly property color panelSurface: Qt.rgba(10 / 255, 12 / 255, 13 / 255, 0.94)
    readonly property color secondarySurface: Qt.rgba(10 / 255, 12 / 255, 13 / 255, 0.88)
    readonly property color utilitySurface: Qt.rgba(10 / 255, 12 / 255, 13 / 255, 0.86)
    readonly property color hoverSurface: Qt.rgba(18 / 255, 20 / 255, 21 / 255, 0.95)
    readonly property color panelBorder: Qt.rgba(1, 1, 1, 0.085)
    readonly property color panelHighlight: Qt.rgba(1, 1, 1, 0.045)
    readonly property color textPrimary: "#e7e9ea"
    readonly property color textSecondary: "#a7abad"
    readonly property color textDim: "#6d7376"
    readonly property color linePrimary: Qt.rgba(1, 1, 1, 0.10)
    readonly property color lineSecondary: Qt.rgba(1, 1, 1, 0.055)
    readonly property color instrumentAccent: "#8fb3c5"
    readonly property color occupiedTone: "#747b7f"
    readonly property color inactiveTone: "#3c4143"
    readonly property string monoFont: "JetBrains Mono"

    readonly property real contextRight: contextIslandItem.x + contextIslandItem.width
    readonly property real clockLeft: clockIslandItem.x
    readonly property real clockRight: clockIslandItem.x + clockIslandItem.width
    readonly property real systemLeft: systemIslandItem.x
    readonly property real systemWidth: systemIslandItem.width
    readonly property bool trayVisible: systemIslandItem.showTray
    readonly property bool metricDetailsVisible: systemIslandItem.showSegments
    readonly property int actualTrayIconLimit: systemIslandItem.trayIconLimit

    signal centerClicked()
    signal systemClicked()
    signal trayPanelToggleRequested(real panelWidth)
    signal trayPanelResizeRequested(real panelWidth)
    signal trayPanelCloseRequested()

    property alias centerIsland: clockIslandItem

    implicitHeight: islandHeight
    color: "transparent"

    ContextIsland {
        id: contextIslandItem
        width: implicitWidth
        height: bar.islandHeight
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: bar.leftIslandOffsetX
        contextState: Core.TopBarState
        niriState: Core.Niri
        screen: bar.currentScreen
        responsiveLevel: bar.layoutMode
        surfaceColor: bar.panelSurface
        borderColor: bar.panelBorder
        highlightColor: bar.panelHighlight
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
        width: implicitWidth
        height: bar.islandHeight
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: bar.centerIslandOffsetX
        responsiveLevel: bar.layoutMode
        showWeather: bar.showWeather
        weatherText: Core.TopBarState.weatherText
        reducedMotion: Core.TopBarState.reducedMotion
        surfaceColor: bar.panelSurface
        hoverColor: bar.hoverSurface
        borderColor: bar.panelBorder
        highlightColor: bar.panelHighlight
        textColor: bar.textPrimary
        textSoft: bar.textSecondary
        textDim: bar.textDim
        lineColor: bar.linePrimary
        accentColor: bar.instrumentAccent
        monoFont: bar.monoFont
        onTogglePanel: bar.centerClicked()
    }

    SystemIsland {
        id: systemIslandItem
        width: implicitWidth
        height: bar.islandHeight
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: -bar.rightIslandOffsetX
        metricsState: Core.TopBarState
        panelWindow: bar.panelWindow
        responsiveLevel: bar.layoutMode
        volumePercent: bar.currentVolume
        requestedTrayIconLimit: bar.responsiveTrayIconLimit
        notificationHistoryCount: bar.notificationHistoryCount
        trayPanelExpanded: bar.trayPanelExpanded
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
        onToggleTrayPanel: panelWidth => bar.trayPanelToggleRequested(panelWidth)
        onResizeTrayPanel: panelWidth => bar.trayPanelResizeRequested(panelWidth)
        onCloseTrayPanel: bar.trayPanelCloseRequested()
    }
}
