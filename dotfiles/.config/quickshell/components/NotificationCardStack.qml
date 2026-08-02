// 两层静态轮廓与一张真实通知卡片。
import "../config" as Config
import QtQuick
import "../config" as Config

Item {
    id: cardStack

    readonly property int animFast: (Config.Theme !== undefined && Config.Theme !== null) ? Config.Theme.animFast : 120
    readonly property int animNormal: (Config.Theme !== undefined && Config.Theme !== null) ? Config.Theme.animNormal : 200

    property var entry: null
    property int entryCount: 0
    property bool ready: false
    property real unit: 13.6
    property color zenInk: Config.Theme.surface
    property color zenStone: Config.Theme.surfaceContainer
    property color zenMist: Config.Theme.outline
    property color zenAsh: Config.Theme.outlineVariant
    property color zenSmoke: Config.Theme.textMuted
    property color zenCloud: Config.Theme.textSecondary
    property color zenSnow: Config.Theme.textPrimary
    property color zenDanger: Config.Theme.danger

    signal copyRequested()
    signal moveRequested(int delta)

    function animateSwitch() {
        // 切换历史卡片：旧内容滑出 + 淡出，随后新内容滑入 + 淡入
        cardSwitchOut.restart()
    }

    function displayTime(timestamp) {
        const date = new Date(Number(timestamp || 0))
        return isNaN(date.getTime())
            ? "UNKNOWN TIME"
            : Qt.formatDateTime(date, "MM-dd HH:mm:ss")
    }

    // 旧内容退场（淡出 + 轻微右移）
    SequentialAnimation {
        id: cardSwitchOut
        ParallelAnimation {
            NumberAnimation {
                target: notificationCard
                property: "opacity"
                to: 0
                duration: cardStack.animFast
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: notificationCard
                property: "x"
                to: cardStack.unit * 0.8 + cardStack.unit * 0.5
                duration: cardStack.animFast
                easing.type: Easing.InCubic
            }
        }
        ScriptAction { script: cardSwitchIn.restart() }
    }

    // 新内容入场（淡入 + 从右侧归位）
    ParallelAnimation {
        id: cardSwitchIn
        NumberAnimation {
            target: notificationCard
            property: "opacity"
            from: 0
            to: 1
            duration: cardStack.animNormal
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: notificationCard
            property: "x"
            from: cardStack.unit * 0.8 + cardStack.unit * 0.5
            to: cardStack.unit * 0.8
            duration: cardStack.animNormal
            easing.type: Easing.OutCubic
        }
    }

    NumberAnimation {
        id: cardReveal
        target: notificationCard
        property: "opacity"
        to: 1
        duration: cardStack.animNormal
        easing.type: Easing.OutQuad
    }
    Rectangle {
        visible: cardStack.ready && cardStack.entryCount > 2
        x: cardStack.unit * 1.15
        y: cardStack.unit * 1.05
        width: parent.width - cardStack.unit * 2.3
        height: parent.height - cardStack.unit * 1.65
        color: "transparent"
        border.color: cardStack.zenAsh
        border.width: 1
        radius: Config.Theme.radiusMedium
        opacity: 0.45
    }

    Rectangle {
        visible: cardStack.ready && cardStack.entryCount > 1
        x: cardStack.unit * 1.0
        y: cardStack.unit * 0.78
        width: parent.width - cardStack.unit * 2.0
        height: parent.height - cardStack.unit * 1.45
        color: cardStack.zenInk
        border.color: cardStack.zenAsh
        border.width: 1
        radius: Config.Theme.radiusMedium
        opacity: 0.72
    }

    Rectangle {
        id: notificationCard
        visible: cardStack.ready && cardStack.entry !== null
        x: cardStack.unit * 0.8
        y: cardStack.unit * 0.5
        width: parent.width - cardStack.unit * 1.6
        height: parent.height - cardStack.unit * 1.25
        color: cardMouse.containsMouse ? cardStack.zenStone : cardStack.zenInk
        border.color: cardStack.entry?.urgency === "Critical"
            ? cardStack.zenDanger
            : cardStack.zenMist
        border.width: 1
        radius: Config.Theme.radiusMedium
        clip: true

        Behavior on color {
            ColorAnimation { duration: Config.Theme.animFast }
        }

        Column {
            anchors.fill: parent
            anchors.margins: cardStack.unit * 0.65
            spacing: cardStack.unit * 0.24

            Text {
                width: parent.width
                text: (cardStack.entry?.appName || "UNKNOWN")
                    + "  ·  " + cardStack.displayTime(cardStack.entry?.timestamp)
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.pixelSize: Math.max(Config.Theme.fontTiny, cardStack.unit * 0.34)
                font.family: "JetBrainsMono Nerd Font"
                color: cardStack.zenCloud
            }
            Text {
                width: parent.width
                text: cardStack.entry?.summary || "(NO TITLE)"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.pixelSize: cardStack.unit * 0.58
                font.bold: true
                font.family: "JetBrainsMono Nerd Font"
                color: cardStack.zenSnow
            }
            Text {
                width: parent.width
                text: cardStack.entry?.body || "(EMPTY BODY)"
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 6
                font.pixelSize: cardStack.unit * 0.43
                lineHeight: 1.18
                font.family: "JetBrainsMono Nerd Font"
                color: cardStack.zenCloud
            }
            Text {
                width: parent.width
                text: (cardStack.entry?.desktopEntry || "NO DESKTOP ENTRY")
                    + "  ·  " + (cardStack.entry?.urgency || "Normal").toUpperCase()
                    + "  ·  #" + String(cardStack.entry?.id ?? 0)
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.pixelSize: Math.max(Config.Theme.fontTiny, cardStack.unit * 0.3)
                font.family: "JetBrainsMono Nerd Font"
                color: cardStack.zenSmoke
            }
        }

        MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cardStack.copyRequested()
            onWheel: wheel => {
                cardStack.moveRequested(wheel.angleDelta.y < 0 ? 1 : -1)
                wheel.accepted = true
            }
        }
    }
}
