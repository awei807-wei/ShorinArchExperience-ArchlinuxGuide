// 右侧子面板中的持久通知历史页。页面只负责历史数据、列表和交互；
// 与 Control 共用固定面板高度，内容超过可用区域后由 ListView 滚动。
import "../config" as Config
import QtQuick
Item {
    id: historyPage

    property var store: null
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
    readonly property var currentEntry: entries.length > 0
        ? entries[Math.max(0, Math.min(currentIndex, entries.length - 1))]
        : null
    readonly property int headerHeight: 58
    readonly property int horizontalPadding: Config.BarTuning.rightPanelPaddingH
        ?? 24
    readonly property int topPadding: Config.BarTuning.rightPanelPaddingTop
        ?? 18
    readonly property int notificationGap: Config.BarTuning.notificationCardGap
        ?? 10
    readonly property int desiredPanelHeight:
        Config.BarTuning.rightPanelHeight ?? 760

    signal closeRequested()
    implicitWidth: panelWidth
    implicitHeight: desiredPanelHeight
    visible: open
    focus: open
    function load() {
        if (!store)
            return
        entries = []
        currentIndex = 0
        panelState = "loading"
        detailMessage = ""
        feedbackMessage = ""
        store.loadHistory()
    }
    function refresh() {
        if (store && open)
            store.loadHistory()
    }
    function switchCard(delta) {
        if (panelState !== "ready" || entries.length < 2)
            return
        currentIndex = (currentIndex + delta + entries.length) % entries.length
        if (notificationList.count > 0)
            notificationList.positionViewAtIndex(currentIndex, ListView.Contain)
        if (!reducedMotion)
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
            historyPage.entries = Array.isArray(items) ? items : []
            historyPage.currentIndex = 0
            historyPage.detailMessage = warning || ""
            historyPage.panelState = historyPage.entries.length > 0 ? "ready" : "empty"
        }

        function onHistoryLoadFailed(message) {
            if (!historyPage.open)
                return
            historyPage.panelState = "error"
            historyPage.detailMessage = message || "Unable to read notification history"
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
            historyPage.detailMessage = message || "Unable to copy notification"
            feedbackTimer.restart()
        }

        function onOperationFailed(operation, message) {
            if (!historyPage.open || operation !== "clear")
                return
            historyPage.panelState = historyPage.entries.length > 0 ? "ready" : "error"
            historyPage.feedbackMessage = "CLEAR ERROR"
            historyPage.detailMessage = message || "Unable to clear notification history"
            feedbackTimer.restart()
        }

        function onHistoryCleared() {
            historyPage.entries = []
            historyPage.currentIndex = 0
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
    SequentialAnimation {
        id: currentCardPulse

        NumberAnimation {
            target: notificationList
            property: "opacity"
            to: 0.86
            duration: Config.Theme.animFast / 2
        }
        NumberAnimation {
            target: notificationList
            property: "opacity"
            to: 1
            duration: Config.Theme.animFast
            easing.type: Easing.OutCubic
        }
    }
    Rectangle {
        anchors.fill: parent
        color: historyPage.zenInk
        radius: Config.BarTuning.rightPanelRadius
        border.width: historyPage.embedded ? 0 : 1
        border.color: historyPage.zenMist
        visible: !historyPage.embedded
    }
    MouseArea {
        anchors.fill: parent
        // 面板内部留白必须消费点击，避免宿主把一次点击误判为外部关闭。
        onClicked: mouse => mouse.accepted = true
    }
    NotificationHistoryHeader {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: historyPage.headerHeight
        entryCount: historyPage.entries.length
        panelState: historyPage.panelState
        feedbackMessage: historyPage.feedbackMessage
        horizontalPadding: historyPage.horizontalPadding
        zenMist: historyPage.zenMist
        zenSmoke: historyPage.zenSmoke
        zenCloud: historyPage.zenCloud
        zenSnow: historyPage.zenSnow
        zenAccent: historyPage.zenAccent
        zenDanger: historyPage.zenDanger
        onClearRequested: historyPage.clearAll()
    }
    Item {
        id: listArea

        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: standaloneFooter.visible ? standaloneFooter.top : parent.bottom
        anchors.topMargin: historyPage.topPadding
        anchors.leftMargin: historyPage.horizontalPadding
        anchors.rightMargin: historyPage.horizontalPadding
        anchors.bottomMargin: 12
        clip: true

        ListView {
            id: notificationList

            anchors.fill: parent
            anchors.rightMargin: 8
            model: historyPage.panelState === "ready" ? historyPage.entries : []
            spacing: historyPage.notificationGap
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            add: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        property: "y"
                        from: -8
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }

            remove: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "opacity"
                        to: 0
                        duration: 120
                    }
                    NumberAnimation {
                        property: "scale"
                        to: 0.98
                        duration: 140
                        easing.type: Easing.InCubic
                    }
                }
            }

            displaced: Transition {
                NumberAnimation {
                    property: "y"
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            delegate: NotificationCardStack {
                required property var modelData
                required property int index

                width: notificationList.width
                entry: modelData
                entryCount: historyPage.entries.length
                ready: historyPage.panelState === "ready"
                selected: index === historyPage.currentIndex
                reducedMotion: historyPage.reducedMotion
                unit: historyPage.unit
                zenInk: historyPage.zenInk
                zenStone: historyPage.zenStone
                zenMist: historyPage.zenMist
                zenAsh: historyPage.zenAsh
                zenSmoke: historyPage.zenSmoke
                zenCloud: historyPage.zenCloud
                zenSnow: historyPage.zenSnow
                zenAccent: historyPage.zenAccent
                zenDanger: historyPage.zenDanger
                onCopyRequested: function(requestedEntry) {
                    historyPage.currentIndex = index
                    historyPage.copyEntry(requestedEntry)
                }
                onMoveRequested: function(delta) {
                    historyPage.switchCard(delta)
                }
            }
        }

        NotificationHistoryEmptyState {
            id: emptyState

            visible: historyPage.panelState === "empty"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(260, parent.width)
            height: 220
            zenSmoke: historyPage.zenSmoke
            zenCloud: historyPage.zenCloud
            zenAccent: historyPage.zenAccent
        }

        NotificationHistoryStatusState {
            id: statusState

            visible: historyPage.panelState === "loading"
                || historyPage.panelState === "clearing"
                || historyPage.panelState === "error"
            anchors.centerIn: parent
            width: Math.min(320, parent.width)
            panelState: historyPage.panelState
            detailMessage: historyPage.detailMessage
            zenSmoke: historyPage.zenSmoke
            zenCloud: historyPage.zenCloud
            zenAccent: historyPage.zenAccent
            zenDanger: historyPage.zenDanger
        }

        MouseArea {
            anchors.fill: parent
            visible: historyPage.panelState === "error"
            cursorShape: Qt.PointingHandCursor
            onClicked: historyPage.load()
        }
    }
    NotificationPanelFooter {
        id: standaloneFooter

        visible: !historyPage.embedded
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        entryCount: historyPage.entries.length
        clearing: historyPage.panelState === "clearing"
        showClearButton: false
        zenMist: historyPage.zenMist
        zenSmoke: historyPage.zenSmoke
        zenDanger: historyPage.zenDanger
        zenAccent: historyPage.zenAccent
        onClearRequested: historyPage.clearAll()
    }
}
