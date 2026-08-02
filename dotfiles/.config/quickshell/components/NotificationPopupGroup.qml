import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import "../config" as Config

Rectangle {
    id: root

    readonly property int animFast: (Config.Theme !== undefined && Config.Theme !== null) ? Config.Theme.animFast : 120
    readonly property int animNormal: (Config.Theme !== undefined && Config.Theme !== null) ? Config.Theme.animNormal : 200

    required property var group
    readonly property var notifications: group?.notifications ?? []
    readonly property string appName: group?.appName ?? "NOTIFICATION"
    readonly property bool critical: group?.critical ?? false
    readonly property string appIconSource: {
        const notification = notifications.find(item =>
            (item?.desktopEntry ?? "").length > 0 || (item?.appIcon ?? "").length > 0)
        if (!notification)
            return ""

        const desktopEntry = String(notification.desktopEntry ?? "").replace(/\.desktop$/, "")
        const appIcon = String(notification.appIcon ?? "")
        const candidates = [desktopEntry, appIcon, appIcon.toLowerCase()]

        for (const candidate of candidates) {
            if (!candidate)
                continue
            if (candidate.startsWith("/"))
                return "file://" + candidate
            if (candidate.includes("://"))
                return candidate
            if (Quickshell.hasThemeIcon(candidate))
                return Quickshell.iconPath(candidate)
        }
        return ""
    }

    function notificationActionEntries(notification) {
        const entries = []
        const actions = notification?.actions ?? []

        for (let actionIndex = 0; actionIndex < actions.length; ++actionIndex) {
            const action = actions[actionIndex]
            if (!action || typeof action.invoke !== "function")
                continue

            const text = String(action.text ?? "").trim()
            if (!text)
                continue

            entries.push({
                "action": action,
                "label": text,
                "notification": notification,
                "owner": root
            })
        }

        return entries
    }
    property real unit: 13.6
    property bool expanded: false
    property color ink: "#101010"
    property color stone: "#1c1c1c"
    property color mist: "#252525"
    property color smoke: "#707070"
    property color cloud: "#999999"
    property color snow: "#d0d0d0"
    property color accent: "#8fb3c5"
    property color danger: "#9a5555"

    signal dismissRequested(var notification)
    signal sourceRequested(var notification)
    signal exitStarted(var notification)
    signal exitFinished()

    width: parent?.width ?? implicitWidth
    implicitHeight: content.implicitHeight + unit * 0.9
    color: headerHover.hovered ? stone : ink
    border.color: critical ? danger : mist
    border.width: 1
    radius: 3
    clip: true

    property bool exiting: false

    Component.onCompleted: reveal.start()

    ParallelAnimation {
        id: reveal
        NumberAnimation {
            target: root
            property: "opacity"
            from: 0
            to: 1
            duration: root.animNormal
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "x"
            from: root.unit
            to: 0
            duration: root.animNormal
            easing.type: Easing.OutCubic
        }
    }

    // 退场：滑出（向右移出）+ 淡出，播放完后发出 exitFinished（由宿主销毁卡片）
    ParallelAnimation {
        id: exitAnim
        NumberAnimation {
            target: root
            property: "x"
            to: root.width + root.unit * 2
            duration: root.animNormal
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: root
            property: "opacity"
            to: 0
            duration: root.animNormal
            easing.type: Easing.InCubic
        }
        onStopped: root.exitFinished()
    }

    function beginExit(notification) {
        if (root.exiting)
            return
        root.exiting = true
        reveal.stop()
        root.exitStarted(notification)
        exitAnim.start()
    }

    // 组内某条通知即将从数据源移除：驱动退场动画（只响应一次）
    onNotificationsChanged: {
        if (!root.exiting && root.notifications.length === 0) {
            const closing = root.__lastNotifications ?? []
            root.beginExit(closing.length > 0 ? closing[closing.length - 1] : null)
        }
        root.__lastNotifications = root.notifications
    }
    property var __lastNotifications: []

    Instantiator {
        model: root.notifications
        delegate: Timer {
            required property var modelData
            interval: 6000
            running: modelData.urgency !== NotificationUrgency.Critical
            repeat: false
            onTriggered: modelData.expire()
        }
    }

    Behavior on implicitHeight {
        NumberAnimation { duration: root.animNormal; easing.type: Easing.OutCubic }
    }

    Behavior on color {
        ColorAnimation { duration: root.animFast }
    }

    // 通知组重排时平滑上移/下移（替代瞬移）
    Behavior on y {
        NumberAnimation { duration: root.animNormal; easing.type: Easing.OutCubic }
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: root.unit * 0.45
        spacing: root.unit * 0.3

        RowLayout {
            id: groupHeader
            width: parent.width
            spacing: root.unit * 0.4

            Rectangle {
                Layout.preferredWidth: root.unit * 1.45
                Layout.preferredHeight: width
                radius: 2
                color: root.mist

                IconImage {
                    id: appIconImage
                    anchors.centerIn: parent
                    width: parent.width * 0.68
                    height: width
                    source: root.appIconSource
                    asynchronous: true
                    visible: root.appIconSource.length > 0 && status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    text: root.appName.slice(0, 1).toUpperCase() || "?"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: root.unit * 0.55
                    font.bold: true
                    color: root.cloud
                    visible: !appIconImage.visible
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: root.appName
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: root.unit * 0.4
                    font.bold: true
                    color: root.snow
                }

                Text {
                    Layout.fillWidth: true
                    text: root.notifications.length === 1
                        ? "NOW"
                        : String(root.notifications.length).padStart(2, "0") + " NOTIFICATIONS"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: root.unit * 0.29
                    color: root.smoke
                }
            }

            Text {
                text: root.expanded ? "−" : "+"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: root.unit * 0.7
                color: root.cloud
            }

            HoverHandler {
                id: headerHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: root.expanded = !root.expanded
                onDoubleTapped: {
                    if (root.notifications.length > 0)
                        root.sourceRequested(root.notifications[0])
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: root.mist }

        Repeater {
            model: root.expanded ? root.notifications : root.notifications.slice(0, 1)

            Column {
                id: noticeRow
                required property int index
                required property var modelData
                readonly property int rowIndex: index
                readonly property var notification: modelData
                readonly property var actionEntries: root.notificationActionEntries(notification)
                width: content.width
                spacing: root.unit * 0.18

                Text {
                    width: parent.width
                    text: noticeRow.notification.summary || "(NO TITLE)"
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: root.unit * 0.52
                    font.bold: true
                    color: root.snow
                }

                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: noticeRow.notification.body || ""
                    textFormat: Text.PlainText
                    wrapMode: root.expanded ? Text.WrapAtWordBoundaryOrAnywhere : Text.NoWrap
                    elide: Text.ElideRight
                    maximumLineCount: root.expanded ? 5 : 1
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: root.unit * 0.42
                    lineHeight: 1.18
                    color: root.cloud

                    Behavior on opacity {
                        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }
                }

                Flickable {
                    width: parent.width
                    height: root.expanded ? root.unit * 1.55 : 0
                    visible: height > 0
                    clip: true
                    contentWidth: Math.max(width, actionRow.implicitWidth)
                    contentHeight: height
                    boundsBehavior: Flickable.StopAtBounds
                    opacity: root.expanded ? 1 : 0

                    Behavior on height {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
                    }

                    Row {
                        id: actionRow
                        height: parent.height
                        spacing: root.unit * 0.3

                        Repeater {
                            model: noticeRow.actionEntries

                            Rectangle {
                                id: actionButton
                                required property var modelData
                                readonly property var nativeAction: modelData.action
                                readonly property var notification: modelData.notification
                                readonly property var owner: modelData.owner
                                readonly property string label: modelData.label
                                height: parent.height
                                width: Math.max(owner.unit * 5, actionLabel.implicitWidth + owner.unit * 1.2)
                                radius: 2
                                color: actionMouse.pressed ? owner.cloud : owner.mist
                                border.color: owner.smoke
                                border.width: 1

                                Text {
                                    id: actionLabel
                                    anchors.centerIn: parent
                                    text: actionButton.label
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: actionButton.owner.unit * 0.35
                                    color: actionMouse.pressed ? actionButton.owner.ink : actionButton.owner.snow
                                }

                                MouseArea {
                                    id: actionMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        actionButton.nativeAction.invoke()
                                        if (!actionButton.notification.resident)
                                            actionButton.owner.dismissRequested(actionButton.notification)
                                    }
                                }
                            }
                        }

                        Rectangle {
                            height: actionRow.height
                            width: root.unit * 4.5
                            radius: 2
                            color: closeMouse.pressed ? root.danger : root.mist
                            border.color: root.smoke
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "DISMISS"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: root.unit * 0.32
                                color: root.snow
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.dismissRequested(noticeRow.notification)
                            }
                        }
                    }
                }

                Rectangle {
                    visible: root.expanded && noticeRow.rowIndex < root.notifications.length - 1
                    width: parent.width
                    height: 1
                    color: root.mist
                }
            }
        }
    }

}
