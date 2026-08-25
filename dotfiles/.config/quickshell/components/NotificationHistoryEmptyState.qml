// 没有历史通知时使用的固定高度空状态。
import "../config" as Config
import QtQuick

Item {
    id: emptyState

    property color zenSmoke: Config.Theme.textMuted
    property color zenCloud: Config.Theme.textSecondary
    property color zenAccent: Config.Theme.accent

    implicitWidth: 260
    implicitHeight: 220

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 24
        width: 36
        height: 36
        radius: 12
        color: Qt.rgba(emptyState.zenAccent.r, emptyState.zenAccent.g,
                        emptyState.zenAccent.b, 0.15)
        border.width: 1
        border.color: Qt.rgba(emptyState.zenAccent.r, emptyState.zenAccent.g,
                               emptyState.zenAccent.b, 0.36)

        Text {
            anchors.centerIn: parent
            text: "·"
            color: emptyState.zenAccent
            font.pixelSize: 24
            font.weight: Font.DemiBold
        }
    }

    Text {
        anchors.top: parent.top
        anchors.topMargin: 78
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "No recent notifications"
        color: emptyState.zenCloud
        font.family: "JetBrains Mono"
        font.pixelSize: 13
    }

    Text {
        anchors.top: parent.top
        anchors.topMargin: 103
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "You're all caught up"
        color: emptyState.zenSmoke
        font.family: "JetBrains Mono"
        font.pixelSize: 11
    }
}
