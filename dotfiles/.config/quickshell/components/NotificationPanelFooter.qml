// 历史页的低存在感操作栏；页面切换器由统一右面板单独承载。
import "../config" as Config
import QtQuick

Item {
    id: footer

    property real unit: 13.6
    property int entryCount: 0
    property bool clearing: false
    property bool showClearButton: true
    property string hintText: "Click a notification to copy · ↑↓ navigate"
    property color zenMist: Config.Theme.outline
    property color zenSmoke: Config.Theme.textMuted
    property color zenDanger: Config.Theme.danger
    property color zenAccent: Config.Theme.accent

    signal clearRequested()

    implicitHeight: Config.BarTuning.rightPanelFooterHeight ?? 58
    height: implicitHeight

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.rgba(footer.zenMist.r, footer.zenMist.g, footer.zenMist.b, 0.45)
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: Config.BarTuning.rightPanelPaddingH ?? 24
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, parent.width - (clearButton.visible ? clearButton.width + 42 : 24))
        text: footer.hintText
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: footer.zenSmoke
        font.family: "JetBrains Mono"
        font.pixelSize: 11
    }

    Rectangle {
        id: clearButton

        visible: footer.showClearButton
        anchors.right: parent.right
        anchors.rightMargin: Config.BarTuning.rightPanelPaddingH ?? 24
        anchors.verticalCenter: parent.verticalCenter
        width: 66
        height: 32
        radius: height / 2
        color: clearMouse.containsMouse
            ? Qt.rgba(footer.zenDanger.r, footer.zenDanger.g,
                      footer.zenDanger.b, 0.18)
            : Qt.rgba(footer.zenMist.r, footer.zenMist.g,
                      footer.zenMist.b, 0.16)
        border.width: 1
        border.color: clearMouse.containsMouse ? footer.zenDanger : footer.zenMist
        opacity: footer.entryCount > 0 && !footer.clearing ? 1 : 0.42

        Text {
            anchors.centerIn: parent
            text: footer.clearing ? "CLEARING" : "CLEAR"
            color: footer.clearing ? footer.zenSmoke : footer.zenDanger
            font.family: "JetBrains Mono"
            font.pixelSize: 10
            font.weight: Font.Medium
            font.letterSpacing: 1
        }

        MouseArea {
            id: clearMouse

            anchors.fill: parent
            enabled: footer.entryCount > 0 && !footer.clearing
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: footer.clearRequested()
        }

        AppToolTip {
            anchors.bottom: parent.top
            anchors.bottomMargin: Config.Theme.spacingTiny
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Clear history"
            target: clearMouse
            enabled: clearMouse.enabled
        }
    }
}
