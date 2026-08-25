import QtQuick

Item {
    id: historyList

    property var entries: []
    property int currentIndex: 0
    property string panelState: "idle"
    property string detailMessage: ""
    property string emptyTitle: "No recent notifications"
    property string emptyDetail: "You're all caught up"
    property bool reducedMotion: false
    property bool sourceSwitching: false
    property real listOpacity: 1
    property int notificationGap: 10
    property real unit: 13.6
    property color zenInk: "#101010"
    property color zenStone: "#1c1c1c"
    property color zenMist: "#252525"
    property color zenAsh: "#404040"
    property color zenSmoke: "#8a8a8a"
    property color zenCloud: "#a8a8a8"
    property color zenSnow: "#d0d0d0"
    property color zenAccent: "#5a9a8a"
    property color zenDanger: "#9a5555"
    readonly property int count: notificationList.count
    readonly property real contentHeight: notificationList.contentHeight

    signal copyRequested(var entry, int index)
    signal moveRequested(int delta)
    signal retryRequested()

    clip: true

    function positionAtIndex(index) {
        if (notificationList.count > 0)
            notificationList.positionViewAtIndex(index, ListView.Contain)
    }

    function positionAtBeginning() {
        if (notificationList.count > 0)
            notificationList.positionViewAtBeginning()
    }

    ListView {
        id: notificationList

        anchors.fill: parent
        anchors.rightMargin: 8
        model: historyList.panelState === "ready" ? historyList.entries : []
        spacing: historyList.notificationGap
        opacity: historyList.listOpacity
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        add: Transition {
            enabled: !historyList.sourceSwitching

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
            enabled: !historyList.sourceSwitching

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
            enabled: !historyList.sourceSwitching
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
            entryCount: historyList.entries.length
            ready: historyList.panelState === "ready"
            selected: index === historyList.currentIndex
            reducedMotion: historyList.reducedMotion
            unit: historyList.unit
            zenInk: historyList.zenInk
            zenStone: historyList.zenStone
            zenMist: historyList.zenMist
            zenAsh: historyList.zenAsh
            zenSmoke: historyList.zenSmoke
            zenCloud: historyList.zenCloud
            zenSnow: historyList.zenSnow
            zenAccent: historyList.zenAccent
            zenDanger: historyList.zenDanger
            onCopyRequested: requestedEntry =>
                historyList.copyRequested(requestedEntry, index)
            onMoveRequested: delta => historyList.moveRequested(delta)
        }
    }

    NotificationHistoryEmptyState {
        visible: historyList.panelState === "empty"
            || (historyList.panelState === "ready"
                && historyList.entries.length === 0)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(260, parent.width)
        height: 220
        opacity: historyList.listOpacity
        title: historyList.emptyTitle
        detail: historyList.emptyDetail
        zenSmoke: historyList.zenSmoke
        zenCloud: historyList.zenCloud
        zenAccent: historyList.zenAccent
    }

    NotificationHistoryStatusState {
        visible: historyList.panelState === "loading"
            || historyList.panelState === "clearing"
            || historyList.panelState === "error"
        anchors.centerIn: parent
        width: Math.min(320, parent.width)
        panelState: historyList.panelState
        detailMessage: historyList.detailMessage
        zenSmoke: historyList.zenSmoke
        zenCloud: historyList.zenCloud
        zenAccent: historyList.zenAccent
        zenDanger: historyList.zenDanger
    }

    MouseArea {
        anchors.fill: parent
        visible: historyList.panelState === "error"
        cursorShape: Qt.PointingHandCursor
        onClicked: historyList.retryRequested()
    }
}
