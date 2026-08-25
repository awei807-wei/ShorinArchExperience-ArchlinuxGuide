// 持久通知历史页的标题与清理操作。
import "../config" as Config
import QtQuick

Item {
    id: header

    property int totalEntryCount: 0
    property int visibleEntryCount: 0
    property string activeSourceLabel: "ALL"
    property string panelState: "idle"
    property string feedbackMessage: ""
    property int horizontalPadding: Config.BarTuning.rightPanelPaddingH ?? 24
    property color zenMist: Config.Theme.outline
    property color zenSmoke: Config.Theme.textMuted
    property color zenCloud: Config.Theme.textSecondary
    property color zenSnow: Config.Theme.textPrimary
    property color zenAccent: Config.Theme.accent
    property color zenDanger: Config.Theme.danger

    implicitHeight: 58
    signal clearRequested()

    Text {
        id: titleText

        anchors.left: parent.left
        anchors.leftMargin: header.horizontalPadding
        anchors.top: parent.top
        anchors.topMargin: 11
        text: "History"
        color: header.zenSnow
        font.family: "JetBrains Mono"
        font.pixelSize: 16
        font.weight: Font.DemiBold
    }

    Text {
        anchors.left: titleText.left
        anchors.top: titleText.bottom
        anchors.topMargin: 2
        text: header.activeSourceLabel === "ALL"
            ? "Recent notifications"
            : header.activeSourceLabel + " notifications"
        color: header.zenSmoke
        font.family: "JetBrains Mono"
        font.pixelSize: 11
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: header.horizontalPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Text {
            text: header.feedbackMessage.length > 0
                ? header.feedbackMessage : String(header.visibleEntryCount)
            color: header.feedbackMessage.indexOf("ERROR") >= 0
                ? header.zenDanger
                : (header.feedbackMessage.length > 0
                    ? header.zenAccent : header.zenCloud)
            font.family: "JetBrains Mono"
            font.pixelSize: 11
            font.weight: Font.Medium
        }

        Rectangle {
            width: 82
            height: 30
            radius: height / 2
            color: clearMouse.containsMouse
                ? Qt.rgba(header.zenDanger.r, header.zenDanger.g,
                          header.zenDanger.b, 0.18)
                : Qt.rgba(header.zenMist.r, header.zenMist.g,
                          header.zenMist.b, 0.16)
            border.width: 1
            border.color: clearMouse.containsMouse
                ? header.zenDanger : header.zenMist
            opacity: header.totalEntryCount > 0
                && header.panelState !== "clearing"
                ? 1 : 0.42

            Text {
                anchors.centerIn: parent
                text: header.panelState === "clearing" ? "CLEARING" : "Clear all"
                color: header.panelState === "clearing"
                    ? header.zenSmoke : header.zenDanger
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                font.weight: Font.Medium
                font.letterSpacing: 0.7
            }

            MouseArea {
                id: clearMouse

                anchors.fill: parent
                enabled: header.totalEntryCount > 0
                    && header.panelState !== "clearing"
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: header.clearRequested()
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: header.horizontalPadding
        anchors.rightMargin: header.horizontalPadding
        height: 1
        color: Qt.rgba(header.zenMist.r, header.zenMist.g,
                       header.zenMist.b, 0.72)
    }
}
