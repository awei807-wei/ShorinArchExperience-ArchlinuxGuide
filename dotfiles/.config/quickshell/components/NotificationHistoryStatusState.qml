// 历史数据加载、清理及存储失败状态的共用展示。
import "../config" as Config
import QtQuick

Item {
    id: statusState

    property string panelState: "idle"
    property string detailMessage: ""
    property color zenSmoke: Config.Theme.textMuted
    property color zenCloud: Config.Theme.textSecondary
    property color zenAccent: Config.Theme.accent
    property color zenDanger: Config.Theme.danger

    implicitWidth: 320
    implicitHeight: statusColumn.implicitHeight

    Column {
        id: statusColumn

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: statusState.panelState === "loading" ? "Loading history"
                : statusState.panelState === "clearing" ? "Clearing history"
                : "Storage error"
            color: statusState.panelState === "error"
                ? statusState.zenDanger : statusState.zenCloud
            font.family: "JetBrains Mono"
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        Text {
            visible: statusState.detailMessage.length > 0
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: statusState.detailMessage
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            color: statusState.zenSmoke
            font.family: "JetBrains Mono"
            font.pixelSize: 11
        }

        Text {
            visible: statusState.panelState === "error"
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Click to retry"
            color: statusState.zenAccent
            font.family: "JetBrains Mono"
            font.pixelSize: 11
        }
    }
}
