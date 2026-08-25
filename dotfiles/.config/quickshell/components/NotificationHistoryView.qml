import "../config" as Config
import QtQuick

Item {
    id: historyView

    property var menuWindow: null
    property var entries: []
    property var filteredEntries: []
    property var sources: []
    property string selectedSourceKey: "__all__"
    property string selectedSourceLabel: "ALL"
    property int currentIndex: 0
    property string panelState: "idle"
    property string feedbackMessage: ""
    property string detailMessage: ""
    property bool embedded: false
    property bool reducedMotion: false
    property bool sourceSwitching: false
    property real unit: 13.6
    property int horizontalPadding: 24
    property int headerHeight: 58
    property int sourceRailHeight: 52
    property int notificationGap: 10
    property color zenInk: Config.Theme.surface
    property color zenStone: Config.Theme.surfaceContainer
    property color zenMist: Config.Theme.outline
    property color zenAsh: Config.Theme.outlineVariant
    property color zenSmoke: Config.Theme.textMuted
    property color zenCloud: Config.Theme.textSecondary
    property color zenSnow: Config.Theme.textPrimary
    property color zenAccent: Config.Theme.accent
    property color zenDanger: Config.Theme.danger
    property alias listOpacity: historyList.listOpacity
    readonly property int listCount: historyList.count

    signal clearRequested()
    signal sourceRequested(string key)
    signal copyRequested(var entry, int index)
    signal moveRequested(int delta)
    signal retryRequested()

    function positionAtIndex(index) {
        historyList.positionAtIndex(index)
    }

    function positionAtBeginning() {
        historyList.positionAtBeginning()
    }

    Rectangle {
        anchors.fill: parent
        color: historyView.zenInk
        radius: Config.BarTuning.rightPanelRadius
        border.width: historyView.embedded ? 0 : 1
        border.color: historyView.zenMist
        visible: !historyView.embedded
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
        height: historyView.headerHeight
        totalEntryCount: historyView.entries.length
        visibleEntryCount: historyView.filteredEntries.length
        activeSourceLabel: historyView.selectedSourceLabel
        panelState: historyView.panelState
        feedbackMessage: historyView.feedbackMessage
        horizontalPadding: historyView.horizontalPadding
        zenMist: historyView.zenMist
        zenSmoke: historyView.zenSmoke
        zenCloud: historyView.zenCloud
        zenSnow: historyView.zenSnow
        zenAccent: historyView.zenAccent
        zenDanger: historyView.zenDanger
        onClearRequested: historyView.clearRequested()
    }

    NotificationSourceRail {
        id: sourceRail

        z: 2
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Config.BarTuning.notificationSourceRailGap
        anchors.leftMargin: historyView.horizontalPadding
        anchors.rightMargin: historyView.horizontalPadding
        height: historyView.sourceRailHeight
        sources: historyView.sources
        selectedSourceKey: historyView.selectedSourceKey
        menuWindow: historyView.menuWindow
        reducedMotion: historyView.reducedMotion
        surfaceColor: historyView.zenInk
        hoverColor: historyView.zenStone
        outlineColor: historyView.zenAsh
        textColor: historyView.zenSnow
        mutedColor: historyView.zenSmoke
        accentColor: historyView.zenAccent
        badgeColor: historyView.zenDanger
        onSourceRequested: key => historyView.sourceRequested(key)
    }

    NotificationHistoryList {
        id: historyList

        anchors.top: sourceRail.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: standaloneFooter.visible
            ? standaloneFooter.top : parent.bottom
        anchors.topMargin: Config.BarTuning.notificationSourceRailGap
        anchors.leftMargin: historyView.horizontalPadding
        anchors.rightMargin: historyView.horizontalPadding
        anchors.bottomMargin: 12
        entries: historyView.filteredEntries
        currentIndex: historyView.currentIndex
        panelState: historyView.panelState
        detailMessage: historyView.detailMessage
        emptyTitle: historyView.selectedSourceKey === "__all__"
            ? "No recent notifications"
            : "No notifications from this source"
        emptyDetail: historyView.selectedSourceKey === "__all__"
            ? "You're all caught up"
            : "This tray app has no saved history"
        reducedMotion: historyView.reducedMotion
        sourceSwitching: historyView.sourceSwitching
        notificationGap: historyView.notificationGap
        unit: historyView.unit
        zenInk: historyView.zenInk
        zenStone: historyView.zenStone
        zenMist: historyView.zenMist
        zenAsh: historyView.zenAsh
        zenSmoke: historyView.zenSmoke
        zenCloud: historyView.zenCloud
        zenSnow: historyView.zenSnow
        zenAccent: historyView.zenAccent
        zenDanger: historyView.zenDanger
        onCopyRequested: (entry, index) =>
            historyView.copyRequested(entry, index)
        onMoveRequested: delta => historyView.moveRequested(delta)
        onRetryRequested: historyView.retryRequested()
    }

    NotificationPanelFooter {
        id: standaloneFooter

        visible: !historyView.embedded
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        entryCount: historyView.entries.length
        clearing: historyView.panelState === "clearing"
        showClearButton: false
        zenMist: historyView.zenMist
        zenSmoke: historyView.zenSmoke
        zenDanger: historyView.zenDanger
        zenAccent: historyView.zenAccent
        onClearRequested: historyView.clearRequested()
    }
}
