pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../config" as Config

Item {
    id: root

    required property var trayItem
    property bool shown: true
    property real itemWidth: Config.BarTuning.trayItemWidth
    property real iconSize: Config.BarTuning.trayIconSize
    property int notificationCount: 0
    property var panelWindow: null
    property bool reducedMotion: false
    property color surfaceColor: Config.Theme.surface
    property color textColor: Config.Theme.textMuted
    property color badgeColor: Config.Theme.danger
    property color badgeTextColor: Config.Theme.textSecondary
    property string monoFont: "JetBrains Mono"

    signal closeRequested()
    signal identityChanged()

    function activateTrayItem() {
        if (trayItem && trayItem.activate) {
            trayItem.activate()
            closeRequested()
        }
    }

    visible: shown
    width: visible ? itemWidth : 0
    height: itemWidth
    opacity: visible ? 1 : 0
    activeFocusOnTab: visible
    Accessible.role: Accessible.Button
    Accessible.name: {
        const title = trayItem && trayItem.title ? trayItem.title : "System tray item"
        return notificationCount > 0
            ? title + ", " + notificationCount + " notifications" : title
    }

    Keys.onReturnPressed: activateTrayItem()
    Keys.onSpacePressed: activateTrayItem()

    Connections {
        // StatusNotifierItem may publish identity fields after registration.
        // Ignore unknown signals so test doubles and older providers remain safe.
        target: root.trayItem && root.trayItem.objectName !== undefined
            ? root.trayItem : null
        ignoreUnknownSignals: true

        function onIdChanged() {
            root.identityChanged()
        }

        function onTitleChanged() {
            root.identityChanged()
        }

        function onTooltipTitleChanged() {
            root.identityChanged()
        }
    }

    Behavior on width {
        enabled: !root.reducedMotion
        NumberAnimation { duration: Config.Theme.animNormal; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        enabled: !root.reducedMotion
        NumberAnimation { duration: Config.Theme.animNormal; easing.type: Easing.OutQuad }
    }

    Rectangle {
        id: background
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        radius: Config.Theme.radiusSmall
        color: pointer.containsMouse ? Config.Theme.surfaceContainer : "transparent"
        border.color: pointer.containsMouse ? Config.Theme.outline : Config.Theme.outlineVariant
        border.width: 1

        Behavior on color {
            enabled: !root.reducedMotion
            ColorAnimation { duration: Config.Theme.animFast }
        }

        Image {
            id: icon
            anchors.centerIn: parent
            width: root.iconSize
            height: root.iconSize
            source: root.trayItem ? root.trayItem.icon : ""
            sourceSize.width: width
            sourceSize.height: height
        }

        Item {
            visible: icon.status === Image.Error || icon.source === ""
            anchors.centerIn: parent
            width: 7
            height: 7

            Rectangle {
                width: 1
                height: parent.height
                anchors.centerIn: parent
                rotation: 45
                color: root.textColor
            }
            Rectangle {
                width: 1
                height: parent.height
                anchors.centerIn: parent
                rotation: -45
                color: root.textColor
            }
        }
    }

    Rectangle {
        visible: root.notificationCount > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Config.BarTuning.trayBadgeTopOffset
        anchors.rightMargin: Config.BarTuning.trayBadgeRightOffset
        height: Config.BarTuning.trayBadgeHeight
        width: Math.max(height, badgeText.implicitWidth + 5)
        radius: height / 2
        color: root.badgeColor
        border.color: root.surfaceColor
        border.width: 1
        z: 3

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: root.notificationCount > 99 ? "99+" : String(root.notificationCount)
            textFormat: Text.PlainText
            font.pixelSize: Config.Theme.fontTiny
            font.weight: Font.DemiBold
            font.family: root.monoFont
            color: root.badgeTextColor
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        color: "transparent"
        border.width: root.activeFocus ? 1 : 0
        border.color: root.textColor
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (root.trayItem && root.trayItem.hasMenu)
                    menuAnchor.open()
            } else {
                root.activateTrayItem()
            }
        }
    }

    QsMenuAnchor {
        id: menuAnchor
        menu: root.trayItem ? root.trayItem.menu : null
        anchor.window: root.panelWindow
        anchor.item: background
    }
}
