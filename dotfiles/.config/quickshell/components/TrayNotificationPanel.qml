// 磁盘通知历史面板：卡片堆视觉，但运行时始终只有一个真实通知卡片。
import "../config" as Config
import QtQuick

Item {
    id: historyPanel

    property var store: null
    property bool open: false
    property real unit: 13.6
    property real panelWidth: unit * 18
    property color zenInk: Config.Theme.surface
    property color zenStone: Config.Theme.surfaceContainer
    property color zenMist: Config.Theme.outline
    property color zenAsh: Config.Theme.outlineVariant
    property color zenSmoke: Config.Theme.textMuted
    property color zenCloud: Config.Theme.textSecondary
    property color zenSnow: Config.Theme.textPrimary
    property color zenAccent: "#5a9a8a"
    property color zenDanger: Config.Theme.danger

    property var entries: []
    property int currentIndex: 0
    property string panelState: "idle"
    property string detailMessage: ""
    property string feedbackMessage: ""
    readonly property var currentEntry: entries.length > 0
        ? entries[Math.max(0, Math.min(currentIndex, entries.length - 1))]
        : null

    signal closeRequested()

    width: panelWidth
    height: unit * 13.2
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
        cardStack.animateSwitch()
    }

    function copyCurrent() {
        if (panelState === "ready" && currentEntry && store)
            store.copyEntry(currentEntry)
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
        } else {
            entries = []
            currentIndex = 0
            panelState = "idle"
            detailMessage = ""
            feedbackMessage = ""
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
        target: historyPanel.store

        function onHistoryLoaded(items, recovered, warning) {
            if (!historyPanel.open) {
                historyPanel.entries = []
                return
            }
            historyPanel.entries = items
            historyPanel.currentIndex = 0
            historyPanel.detailMessage = warning || ""
            historyPanel.panelState = items.length > 0 ? "ready" : "empty"
        }

        function onHistoryLoadFailed(message) {
            if (!historyPanel.open)
                return
            historyPanel.panelState = "error"
            historyPanel.detailMessage = message
        }

        function onHistoryAppended() {
            if (historyPanel.open)
                historyRefreshTimer.restart()
        }

        function onCopySucceeded() {
            if (!historyPanel.open)
                return
            historyPanel.feedbackMessage = "COPIED"
            feedbackTimer.restart()
        }

        function onCopyFailed(message) {
            if (!historyPanel.open)
                return
            historyPanel.feedbackMessage = "COPY ERROR"
            historyPanel.detailMessage = message
            feedbackTimer.restart()
        }

        function onOperationFailed(operation, message) {
            if (!historyPanel.open || operation !== "clear")
                return
            historyPanel.panelState = historyPanel.entries.length > 0 ? "ready" : "error"
            historyPanel.feedbackMessage = "CLEAR ERROR"
            historyPanel.detailMessage = message
            feedbackTimer.restart()
        }

        function onHistoryCleared() {
            historyPanel.entries = []
            historyPanel.currentIndex = 0
            historyPanel.panelState = "empty"
            historyPanel.feedbackMessage = "CLEARED"
            historyPanel.closeRequested()
        }
    }

    Timer {
        id: feedbackTimer
        interval: 1400
        onTriggered: historyPanel.feedbackMessage = ""
    }

    Timer {
        id: historyRefreshTimer
        interval: 80
        onTriggered: historyPanel.refresh()
    }

    // 柔和投影（底下垫一层偏移 2px 的半透明黑矩形）
    Rectangle {
        z: -1
        anchors.fill: parent
        anchors.topMargin: 2
        radius: Config.Theme.radiusLarge
        color: "#000000"
        opacity: 0.35
    }

    Rectangle {
        id: panelSurface
        anchors.fill: parent
        color: historyPanel.zenInk
        border.color: historyPanel.zenMist
        border.width: 1
        radius: Config.Theme.radiusLarge
        opacity: historyPanel.open ? 1 : 0
        transform: Translate {
            y: historyPanel.open ? 0 : -historyPanel.unit * 0.7
            Behavior on y {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
        }

        MouseArea {
            anchors.fill: parent
            // 吞掉面板内部空白处的点击，避免触发宿主的外部关闭层。
            onClicked: mouse => mouse.accepted = true
        }

        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: historyPanel.unit * 1.55

            Text {
                anchors.left: parent.left
                anchors.leftMargin: historyPanel.unit * 0.8
                anchors.verticalCenter: parent.verticalCenter
                text: "HISTORY"
                font.pixelSize: historyPanel.unit * 0.4
                font.bold: true
                font.family: "JetBrainsMono Nerd Font"
                color: historyPanel.zenSnow
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: historyPanel.unit * 0.8
                anchors.verticalCenter: parent.verticalCenter
                text: historyPanel.feedbackMessage.length > 0
                    ? historyPanel.feedbackMessage
                    : (historyPanel.entries.length > 0
                        ? String(historyPanel.currentIndex + 1).padStart(2, "0")
                            + "/" + String(historyPanel.entries.length).padStart(2, "0")
                        : historyPanel.panelState.toUpperCase())
                font.pixelSize: Math.max(Config.Theme.fontTiny, historyPanel.unit * 0.34)
                font.family: "JetBrainsMono Nerd Font"
                color: historyPanel.feedbackMessage.indexOf("ERROR") >= 0
                    ? historyPanel.zenDanger
                    : (historyPanel.feedbackMessage.length > 0
                        ? historyPanel.zenAccent
                        : historyPanel.zenCloud)
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: historyPanel.unit * 0.8
                anchors.rightMargin: historyPanel.unit * 0.8
                height: 1
                color: historyPanel.zenMist
            }
        }

        Item {
            id: cardStage
            anchors.top: header.bottom
            anchors.bottom: footer.top
            anchors.left: parent.left
            anchors.right: parent.right
            clip: true

            NotificationCardStack {
                id: cardStack
                anchors.fill: parent
                entry: historyPanel.currentEntry
                entryCount: historyPanel.entries.length
                ready: historyPanel.panelState === "ready"
                unit: historyPanel.unit
                zenInk: historyPanel.zenInk
                zenStone: historyPanel.zenStone
                zenMist: historyPanel.zenMist
                zenAsh: historyPanel.zenAsh
                zenSmoke: historyPanel.zenSmoke
                zenCloud: historyPanel.zenCloud
                zenSnow: historyPanel.zenSnow
                zenDanger: historyPanel.zenDanger
                onCopyRequested: historyPanel.copyCurrent()
                onMoveRequested: delta => historyPanel.switchCard(delta)
            }

            Column {
                visible: historyPanel.panelState !== "ready"
                anchors.centerIn: parent
                width: parent.width - historyPanel.unit * 3
                spacing: historyPanel.unit * 0.45

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: historyPanel.panelState === "loading" ? "LOADING HISTORY"
                        : historyPanel.panelState === "clearing" ? "CLEARING HISTORY"
                        : historyPanel.panelState === "error" ? "STORAGE ERROR"
                        : "EMPTY"
                    font.pixelSize: historyPanel.unit * 0.46
                    font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                    color: historyPanel.panelState === "error"
                        ? historyPanel.zenDanger
                        : historyPanel.zenCloud
                }
                Text {
                    visible: historyPanel.detailMessage.length > 0
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: historyPanel.detailMessage
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    font.pixelSize: Math.max(Config.Theme.fontTiny, historyPanel.unit * 0.32)
                    font.family: "JetBrainsMono Nerd Font"
                    color: historyPanel.zenSmoke
                }
                Text {
                    visible: historyPanel.panelState === "error"
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "CLICK TO RETRY"
                    font.pixelSize: Math.max(Config.Theme.fontTiny, historyPanel.unit * 0.31)
                    font.family: "JetBrainsMono Nerd Font"
                    color: historyPanel.zenAccent
                }
            }

            MouseArea {
                visible: historyPanel.panelState === "error"
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: historyPanel.load()
            }
        }

        NotificationPanelFooter {
            id: footer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            unit: historyPanel.unit
            entryCount: historyPanel.entries.length
            clearing: historyPanel.panelState === "clearing"
            zenMist: historyPanel.zenMist
            zenSmoke: historyPanel.zenSmoke
            zenDanger: historyPanel.zenDanger
            onClearRequested: historyPanel.clearAll()
        }
    }
}
