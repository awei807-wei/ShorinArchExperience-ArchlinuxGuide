// 右侧子面板中的持久通知历史页。来源模型统一复用系统托盘身份匹配，
// 页面只维护筛选选择、历史加载和列表交互。
import "../config" as Config
import QtQuick
import "TrayNotificationModel.js" as TrayModel

Item {
    id: historyPage

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
    property var entries: []
    property int currentIndex: 0
    property string panelState: "idle"
    property string detailMessage: ""
    property string feedbackMessage: ""
    property string selectedSourceKey: "__all__"
    property var selectedSourceAliases: ["__all__"]
    property string pendingSourceKey: "__all__"
    property bool sourceSwitching: false
    readonly property var sources: {
        const revision = trayModelRevision
        const counts = store && store.sourceCounts !== undefined
            ? store.sourceCounts : []
        return TrayModel.buildHistorySources(
            entries, trayItems, counts)
    }
    readonly property var selectedSource:
        TrayModel.sourceForKey(sources, selectedSourceKey)
            || (sources.length > 0 ? sources[0] : null)
    readonly property var filteredEntries: selectedSource
        && Array.isArray(selectedSource.entries)
        ? selectedSource.entries : []

    readonly property var currentEntry: filteredEntries.length > 0
        ? filteredEntries[Math.max(
            0, Math.min(currentIndex, filteredEntries.length - 1))]
        : null
    readonly property int headerHeight: 58
    readonly property int sourceRailHeight:
        Config.BarTuning.notificationSourceRailHeight
    readonly property int sourceRailSpacing:
        Config.BarTuning.notificationSourceRailGap * 2
    readonly property int horizontalPadding:
        Config.BarTuning.rightPanelPaddingH ?? 24
    readonly property int notificationGap:
        Config.BarTuning.notificationCardGap ?? 10
    // 当前统一右面板外壳固定 760px；来源栏只重新分配页内空间。
    readonly property int desiredPanelHeight:
        Config.BarTuning.rightPanelHeight ?? 760

    signal closeRequested()

    implicitWidth: panelWidth
    implicitHeight: desiredPanelHeight
    visible: open
    focus: open

    function sourceAliases(source) {
        return source && Array.isArray(source.aliases)
            ? source.aliases.slice() : []
    }

    function reconcileSelection(previousKey, previousAliases) {
        const nextKey = TrayModel.sourceKeyForSelection(
            sources, previousKey, previousAliases)
        const nextSource = TrayModel.sourceForKey(sources, nextKey)
            || (sources.length > 0 ? sources[0] : null)
        const sourceChanged = selectedSourceKey !== nextKey
        selectedSourceKey = nextKey
        selectedSourceAliases = sourceAliases(nextSource)
        if (sourceChanged)
            currentIndex = 0
        else
            currentIndex = Math.max(0, Math.min(
                currentIndex, filteredEntries.length - 1))
    }

    function load() {
        if (!store)
            return
        panelState = "loading"
        entries = []
        currentIndex = 0
        detailMessage = ""
        feedbackMessage = ""
        store.loadHistory()
    }

    function refresh() {
        if (store && open)
            store.loadHistory()
    }

    function switchCard(delta) {
        const count = filteredEntries.length
        if (panelState !== "ready" || count < 2)
            return
        currentIndex = (currentIndex + delta + count) % count
        historyView.positionAtIndex(currentIndex)
        if (!reducedMotion && !sourceSwitching)
            currentCardPulse.restart()
    }

    function copyCurrent() {
        copyEntry(currentEntry)
    }

    function copyEntry(entry) {
        if (panelState === "ready" && entry && store)
            store.copyEntry(entry)
    }

    function clearAll() {
        if (!store || panelState === "clearing" || entries.length === 0)
            return
        panelState = "clearing"
        feedbackMessage = "CLEARING"
        store.clearHistory()
    }

    function applySourceSelection(key) {
        const source = TrayModel.sourceForKey(sources, key)
        if (!source)
            return
        selectedSourceKey = source.key
        selectedSourceAliases = sourceAliases(source)
        currentIndex = 0
        Qt.callLater(historyView.positionAtBeginning)
    }

    function selectSource(key) {
        if (!TrayModel.sourceForKey(sources, key))
            return
        if (sourceSwitching && pendingSourceKey === key)
            return
        if (!sourceSwitching && selectedSourceKey === key)
            return

        pendingSourceKey = key
        if (reducedMotion) {
            sourceSwitchFadeOut.stop()
            sourceSwitchFadeIn.stop()
            historyView.listOpacity = 1
            sourceSwitching = false
            applySourceSelection(key)
            return
        }

        sourceSwitchFadeOut.stop()
        sourceSwitchFadeIn.stop()
        historyView.listOpacity = 1
        sourceSwitching = true
        sourceSwitchFadeOut.restart()
    }

    onSourcesChanged: {
        if (panelState !== "loading")
            selectionReconcileTimer.restart()
    }

    onFilteredEntriesChanged: {
        currentIndex = Math.max(0, Math.min(
            currentIndex, filteredEntries.length - 1))
    }

    onOpenChanged: {
        if (open) {
            load()
            Qt.callLater(forceActiveFocus)
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Down) {
            switchCard(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            switchCard(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            copyCurrent()
            event.accepted = true
        } else if (event.key === Qt.Key_Delete) {
            clearAll()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            closeRequested()
            event.accepted = true
        }
    }

    Connections {
        target: historyPage.store

        function onHistoryLoaded(items, recovered, warning) {
            if (!historyPage.open)
                return
            const previousKey = historyPage.selectedSourceKey
            const previousAliases = historyPage.selectedSourceAliases.slice()
            historyPage.entries = Array.isArray(items) ? items : []
            historyPage.currentIndex = 0
            historyPage.detailMessage = warning || ""
            historyPage.panelState = historyPage.entries.length > 0
                ? "ready" : "empty"
            Qt.callLater(function() {
                historyPage.reconcileSelection(previousKey, previousAliases)
            })
        }

        function onHistoryLoadFailed(message) {
            if (!historyPage.open)
                return
            historyPage.panelState = "error"
            historyPage.detailMessage = message
                || "Unable to read notification history"
        }

        function onHistoryAppended() {
            if (historyPage.open)
                historyRefreshTimer.restart()
        }

        function onCopySucceeded() {
            if (!historyPage.open)
                return
            historyPage.feedbackMessage = "COPIED"
            feedbackTimer.restart()
        }

        function onCopyFailed(message) {
            if (!historyPage.open)
                return
            historyPage.feedbackMessage = "COPY ERROR"
            historyPage.detailMessage = message
                || "Unable to copy notification"
            feedbackTimer.restart()
        }

        function onOperationFailed(operation, message) {
            if (!historyPage.open || operation !== "clear")
                return
            historyPage.panelState = historyPage.entries.length > 0
                ? "ready" : "error"
            historyPage.feedbackMessage = "CLEAR ERROR"
            historyPage.detailMessage = message
                || "Unable to clear notification history"
            feedbackTimer.restart()
        }

        function onHistoryCleared() {
            historyPage.entries = []
            historyPage.currentIndex = 0
            historyPage.selectedSourceKey = "__all__"
            historyPage.selectedSourceAliases = ["__all__"]
            historyPage.panelState = "empty"
            historyPage.feedbackMessage = "CLEARED"
            historyPage.closeRequested()
        }
    }

    Timer {
        id: feedbackTimer
        interval: 1400
        onTriggered: historyPage.feedbackMessage = ""
    }

    Timer {
        id: historyRefreshTimer
        interval: 80
        onTriggered: historyPage.refresh()
    }

    Timer {
        id: selectionReconcileTimer
        interval: 0
        onTriggered: historyPage.reconcileSelection(
            historyPage.selectedSourceKey,
            historyPage.selectedSourceAliases)
    }

    SequentialAnimation {
        id: currentCardPulse

        NumberAnimation {
            target: historyView
            property: "listOpacity"
            to: 0.86
            duration: Config.Theme.animFast / 2
        }
        NumberAnimation {
            target: historyView
            property: "listOpacity"
            to: 1
            duration: Config.Theme.animFast
            easing.type: Easing.OutCubic
        }
    }

    NumberAnimation {
        id: sourceSwitchFadeOut
        target: historyView
        property: "listOpacity"
        to: 0.35
        duration: 60
        easing.type: Easing.InCubic
        onFinished: {
            historyPage.applySourceSelection(historyPage.pendingSourceKey)
            sourceSwitchFadeIn.restart()
        }
    }

    NumberAnimation {
        id: sourceSwitchFadeIn
        target: historyView
        property: "listOpacity"
        to: 1
        duration: 120
        easing.type: Easing.OutCubic
        onFinished: historyPage.sourceSwitching = false
    }

    NotificationHistoryView {
        id: historyView

        anchors.fill: parent
        menuWindow: historyPage.menuWindow
        entries: historyPage.entries
        filteredEntries: historyPage.filteredEntries
        sources: historyPage.sources
        selectedSourceKey: historyPage.selectedSourceKey
        selectedSourceLabel: historyPage.selectedSource
            ? historyPage.selectedSource.label : "ALL"
        currentIndex: historyPage.currentIndex
        panelState: historyPage.panelState
        feedbackMessage: historyPage.feedbackMessage
        detailMessage: historyPage.detailMessage
        embedded: historyPage.embedded
        reducedMotion: historyPage.reducedMotion
        sourceSwitching: historyPage.sourceSwitching
        unit: historyPage.unit
        horizontalPadding: historyPage.horizontalPadding
        headerHeight: historyPage.headerHeight
        sourceRailHeight: historyPage.sourceRailHeight
        notificationGap: historyPage.notificationGap
        zenInk: historyPage.zenInk
        zenStone: historyPage.zenStone
        zenMist: historyPage.zenMist
        zenAsh: historyPage.zenAsh
        zenSmoke: historyPage.zenSmoke
        zenCloud: historyPage.zenCloud
        zenSnow: historyPage.zenSnow
        zenAccent: historyPage.zenAccent
        zenDanger: historyPage.zenDanger
        onClearRequested: historyPage.clearAll()
        onSourceRequested: key => historyPage.selectSource(key)
        onCopyRequested: (entry, index) => {
            historyPage.currentIndex = index
            historyPage.copyEntry(entry)
        }
        onMoveRequested: delta => historyPage.switchCard(delta)
        onRetryRequested: historyPage.load()
    }
}
