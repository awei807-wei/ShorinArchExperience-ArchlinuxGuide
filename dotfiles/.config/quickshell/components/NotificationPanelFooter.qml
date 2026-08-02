// 通知面板底部导航提示与破坏性清理操作。
import "../config" as Config
import QtQuick

Item {
    id: footer

    property real unit: 13.6
    property int entryCount: 0
    property bool clearing: false
    property color zenMist: Config.Theme.outline
    property color zenSmoke: Config.Theme.textMuted
    property color zenDanger: Config.Theme.danger

    signal clearRequested()

    height: unit * 1.75

    Text {
        anchors.left: parent.left
        anchors.leftMargin: footer.unit * 0.8
        anchors.verticalCenter: parent.verticalCenter
        text: "SCROLL ↑↓  ·  ENTER COPY"
        font.pixelSize: Math.max(Config.Theme.fontTiny, footer.unit * 0.29)
        font.family: "JetBrainsMono Nerd Font"
        color: footer.zenSmoke
    }

    Rectangle {
        id: clearButton
        property bool hovered: false
        anchors.right: parent.right
        anchors.rightMargin: footer.unit * 0.62
        anchors.verticalCenter: parent.verticalCenter
        width: footer.unit * 1.25
        height: footer.unit * 1.15
        radius: Config.Theme.radiusSmall
        color: hovered ? Qt.rgba(0.6, 0.25, 0.25, 0.18) : "transparent"
        border.color: hovered ? footer.zenDanger : footer.zenMist
        border.width: 1
        opacity: footer.entryCount > 0 && !footer.clearing ? 1 : 0.35

        Behavior on color {
            ColorAnimation { duration: Config.Theme.animFast }
        }

        Behavior on border.color {
            ColorAnimation { duration: Config.Theme.animFast }
        }

        Item {
            anchors.centerIn: parent
            width: footer.unit * 0.48
            height: footer.unit * 0.58
            Rectangle {
                x: 1
                y: footer.unit * 0.14
                width: parent.width - 2
                height: parent.height - footer.unit * 0.14
                color: "transparent"
                border.color: footer.zenDanger
                border.width: 1
                radius: 1
            }
            Rectangle {
                x: 0
                y: footer.unit * 0.07
                width: parent.width
                height: 1
                color: footer.zenDanger
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                width: parent.width * 0.45
                height: 1
                color: footer.zenDanger
            }
        }

        MouseArea {
            id: clearMouse
            anchors.fill: parent
            enabled: footer.entryCount > 0 && !footer.clearing
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onEntered: clearButton.hovered = true
            onExited: clearButton.hovered = false
            onPressed: clearButton.scale = 0.94
            onReleased: clearButton.scale = 1
            onCanceled: clearButton.scale = 1
            onClicked: footer.clearRequested()
        }

        AppToolTip {
            anchors.bottom: parent.top
            anchors.bottomMargin: Config.Theme.spacingTiny
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Clear History"
            target: clearMouse
            enabled: footer.entryCount > 0 && !footer.clearing
        }
    }
}
