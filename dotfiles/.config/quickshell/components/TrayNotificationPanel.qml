// 旧名称兼容层：生产右侧子面板使用 NotificationHistoryPage，
// 这里保留历史面板原有的属性和方法，避免旧宿主与状态检查断裂。
import "../config" as Config
import QtQuick

Item {
    id: historyPanel

    property var store: null
    property var menuWindow: null
    property var trayItems: []
    property int trayModelRevision: 0
    property bool open: false
    property bool embedded: false
    property bool reducedMotion: false
    property real unit: 13.6
    property real panelWidth: unit * 46
    property color zenInk: Config.Theme.surface
    property color zenStone: Config.Theme.surfaceContainer
    property color zenMist: Config.Theme.outline
    property color zenAsh: Config.Theme.outlineVariant
    property color zenSmoke: Config.Theme.textMuted
    property color zenCloud: Config.Theme.textSecondary
    property color zenSnow: Config.Theme.textPrimary
    property color zenAccent: Config.Theme.accent
    property color zenDanger: Config.Theme.danger

    property alias entries: historyPage.entries
    property alias currentIndex: historyPage.currentIndex
    property alias panelState: historyPage.panelState
    property alias detailMessage: historyPage.detailMessage
    property alias feedbackMessage: historyPage.feedbackMessage
    property alias selectedSourceKey: historyPage.selectedSourceKey
    readonly property var sources: historyPage.sources
    readonly property var filteredEntries: historyPage.filteredEntries
    readonly property var currentEntry: historyPage.currentEntry
    readonly property int desiredPanelHeight: historyPage.desiredPanelHeight

    signal closeRequested()

    implicitWidth: panelWidth
    implicitHeight: desiredPanelHeight
    visible: open
    focus: open

    function load() {
        historyPage.load()
    }

    function refresh() {
        historyPage.refresh()
    }

    function switchCard(delta) {
        historyPage.switchCard(delta)
    }

    function copyCurrent() {
        historyPage.copyCurrent()
    }

    function clearAll() {
        historyPage.clearAll()
    }

    function selectSource(key) {
        historyPage.selectSource(key)
    }

    NotificationHistoryPage {
        id: historyPage

        anchors.fill: parent
        store: historyPanel.store
        menuWindow: historyPanel.menuWindow
        trayItems: historyPanel.trayItems
        trayModelRevision: historyPanel.trayModelRevision
        open: historyPanel.open
        embedded: historyPanel.embedded
        reducedMotion: historyPanel.reducedMotion
        unit: historyPanel.unit
        panelWidth: historyPanel.panelWidth
        zenInk: historyPanel.zenInk
        zenStone: historyPanel.zenStone
        zenMist: historyPanel.zenMist
        zenAsh: historyPanel.zenAsh
        zenSmoke: historyPanel.zenSmoke
        zenCloud: historyPanel.zenCloud
        zenSnow: historyPanel.zenSnow
        zenAccent: historyPanel.zenAccent
        zenDanger: historyPanel.zenDanger
        onCloseRequested: historyPanel.closeRequested()
    }
}
