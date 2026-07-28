pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Rectangle {
    id: trayIsland

    property real unit: 8
    property color zenInk: Qt.rgba(10 / 255, 12 / 255, 13 / 255, 0.86)
    property color zenMist: Qt.rgba(1, 1, 1, 0.085)
    property color zenStone: Qt.rgba(1, 1, 1, 0.025)
    property color zenAsh: Qt.rgba(1, 1, 1, 0.055)
    property color zenCloud: "#6d7376"
    property color zenSnow: "#a7abad"
    property color zenDanger: "#9a5555"
    property color highlightColor: Qt.rgba(1, 1, 1, 0.045)
    property string monoFont: "JetBrains Mono"
    property var panelWindow: null
    property var trayItems: SystemTray.items
    property int directIconLimit: 3
    property int notificationCount: 0
    property bool expanded: false
    property bool reducedMotion: false
    property real preferredWidth: 0

    readonly property int trayCount: {
        if (Array.isArray(trayItems))
            return trayItems.length
        if (trayItems && trayItems.values)
            return trayItems.values.length
        if (trayItems && trayItems.count !== undefined)
            return trayItems.count
        return 0
    }
    readonly property int hiddenTrayCount: Math.max(0, trayCount - directIconLimit)
    readonly property bool hasCompositeEntry: hiddenTrayCount > 0 || notificationCount > 0
    readonly property int collapsedSlots: Math.min(trayCount, directIconLimit)
        + (hasCompositeEntry ? 1 : 0)
    readonly property real itemWidth: 17
    readonly property real iconSize: 16
    readonly property real itemGap: 6
    readonly property real horizontalPadding: 32
    readonly property real expandedContentWidth: (trayCount + 1) * itemWidth
        + Math.max(0, trayCount) * itemGap + horizontalPadding
    readonly property real expandedWidth: Math.max(unit * 18, expandedContentWidth)

    signal toggleRequested(real panelWidth)
    signal closeRequested()

    implicitWidth: collapsedSlots === 0 ? 20
        : collapsedSlots * itemWidth
            + Math.max(0, collapsedSlots - 1) * itemGap
            + horizontalPadding
    implicitHeight: 38
    width: preferredWidth > 0 ? preferredWidth : implicitWidth
    color: zenInk
    border.color: zenMist
    border.width: 1
    radius: 3
    clip: false

    onHasCompositeEntryChanged: {
        if (!hasCompositeEntry && expanded)
            closeRequested()
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: trayIsland.highlightColor
        z: 4
    }

    Rectangle {
        id: expandedSurface
        z: 0
        visible: trayIsland.expanded
        x: trayIsland.width - trayIsland.expandedWidth
        width: trayIsland.expandedWidth
        height: parent.height
        color: trayIsland.zenInk
        border.color: trayIsland.zenMist
        border.width: 1
        radius: 3
        opacity: visible ? 1 : 0

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: trayIsland.highlightColor
        }

        Behavior on opacity {
            enabled: !trayIsland.reducedMotion
            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
        }
    }

    Row {
        id: trayRow
        z: 2
        anchors.right: parent.right
        anchors.rightMargin: trayIsland.horizontalPadding / 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: trayIsland.itemGap

        Repeater {
            model: trayIsland.trayItems

            Item {
                id: trayItemContainer

                required property int index
                required property var modelData
                visible: trayIsland.expanded || index < trayIsland.directIconLimit
                width: visible ? trayIsland.itemWidth : 0
                height: trayIsland.itemWidth
                opacity: visible ? 1 : 0
                activeFocusOnTab: visible
                Accessible.role: Accessible.Button
                Accessible.name: modelData && modelData.title ? modelData.title : "System tray item"

                Keys.onReturnPressed: activateTrayItem()
                Keys.onSpacePressed: activateTrayItem()

                function activateTrayItem() {
                    if (modelData && modelData.activate) {
                        modelData.activate()
                        trayIsland.closeRequested()
                    }
                }

                Behavior on width {
                    enabled: !trayIsland.reducedMotion
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    enabled: !trayIsland.reducedMotion
                    NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
                }

                Rectangle {
                    id: trayItemBackground
                    anchors.fill: parent
                    color: trayItemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.025) : "transparent"
                    border.color: trayItemMouse.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1

                    Image {
                        id: trayIcon
                        anchors.centerIn: parent
                        width: trayIsland.iconSize
                        height: trayIsland.iconSize
                        source: trayItemContainer.modelData ? trayItemContainer.modelData.icon : ""
                        sourceSize.width: width
                        sourceSize.height: height
                    }

                    Item {
                        visible: trayIcon.status === Image.Error || trayIcon.source === ""
                        anchors.centerIn: parent
                        width: 7
                        height: 7

                        Rectangle {
                            width: 1
                            height: parent.height
                            anchors.centerIn: parent
                            rotation: 45
                            color: trayIsland.zenCloud
                        }
                        Rectangle {
                            width: 1
                            height: parent.height
                            anchors.centerIn: parent
                            rotation: -45
                            color: trayIsland.zenCloud
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    color: "transparent"
                    border.width: trayItemContainer.activeFocus ? 1 : 0
                    border.color: trayIsland.zenCloud
                }

                MouseArea {
                    id: trayItemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        trayItemContainer.forceActiveFocus()
                        if (mouse.button === Qt.RightButton) {
                            if (trayItemContainer.modelData && trayItemContainer.modelData.hasMenu)
                                menuAnchor.open()
                        } else {
                            trayItemContainer.activateTrayItem()
                        }
                    }
                }

                QsMenuAnchor {
                    id: menuAnchor
                    menu: trayItemContainer.modelData ? trayItemContainer.modelData.menu : null
                    anchor.window: trayIsland.panelWindow
                    anchor.item: trayItemBackground
                }
            }
        }

        Item {
            id: compositeEntry

            property bool hovered: false
            visible: !trayIsland.expanded && trayIsland.hasCompositeEntry
            width: visible ? trayIsland.itemWidth : 0
            height: trayIsland.itemWidth
            opacity: visible ? 1 : 0
            activeFocusOnTab: visible
            Accessible.role: Accessible.Button
            Accessible.name: "More tray items and notification history"

            Keys.onReturnPressed: trayIsland.toggleRequested(trayIsland.expandedWidth)
            Keys.onSpacePressed: trayIsland.toggleRequested(trayIsland.expandedWidth)

            Behavior on width {
                enabled: !trayIsland.reducedMotion
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                enabled: !trayIsland.reducedMotion
                NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
            }

            Rectangle {
                anchors.fill: parent
                color: compositeEntry.hovered ? Qt.rgba(1, 1, 1, 0.025) : "transparent"
                border.color: compositeEntry.hovered
                    ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
            }

            Text {
                visible: trayIsland.hiddenTrayCount > 0
                anchors.centerIn: parent
                text: "+" + trayIsland.hiddenTrayCount
                textFormat: Text.PlainText
                font.pixelSize: 6
                font.family: trayIsland.monoFont
                color: trayIsland.zenCloud
            }

            Item {
                visible: trayIsland.hiddenTrayCount === 0 && trayIsland.notificationCount > 0
                anchors.centerIn: parent
                width: 9
                height: 9

                Rectangle {
                    x: 2
                    y: 0
                    width: 7
                    height: 6
                    color: "transparent"
                    border.color: trayIsland.zenCloud
                    border.width: 1
                }
                Rectangle {
                    x: 0
                    y: 3
                    width: 7
                    height: 6
                    color: trayIsland.zenInk
                    border.color: trayIsland.zenCloud
                    border.width: 1
                }
            }

            Rectangle {
                visible: trayIsland.notificationCount > 0
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: -4
                anchors.rightMargin: -5
                height: 10
                width: Math.max(height, notificationBadgeText.implicitWidth + 5)
                radius: height / 2
                color: trayIsland.zenDanger
                border.color: trayIsland.zenInk
                border.width: 1

                Text {
                    id: notificationBadgeText
                    anchors.centerIn: parent
                    text: trayIsland.notificationCount > 99 ? "99+" : String(trayIsland.notificationCount)
                    textFormat: Text.PlainText
                    font.pixelSize: 5
                    font.weight: Font.DemiBold
                    font.family: trayIsland.monoFont
                    color: trayIsland.zenSnow
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                color: "transparent"
                border.width: compositeEntry.activeFocus ? 1 : 0
                border.color: trayIsland.zenCloud
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: compositeEntry.hovered = true
                onExited: compositeEntry.hovered = false
                onClicked: {
                    compositeEntry.forceActiveFocus()
                    trayIsland.toggleRequested(trayIsland.expandedWidth)
                }
            }
        }

        Item {
            id: collapseButton

            property bool hovered: false
            visible: trayIsland.expanded
            width: visible ? trayIsland.itemWidth : 0
            height: trayIsland.itemWidth
            opacity: visible ? 1 : 0
            activeFocusOnTab: visible

            Text {
                anchors.centerIn: parent
                text: "«"
                font.pixelSize: 8
                font.family: trayIsland.monoFont
                color: collapseButton.hovered ? trayIsland.zenSnow : trayIsland.zenCloud
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: collapseButton.hovered = true
                onExited: collapseButton.hovered = false
                onClicked: trayIsland.closeRequested()
            }
        }

        Text {
            visible: trayIsland.trayCount === 0
                && trayIsland.notificationCount === 0
                && !trayIsland.expanded
            anchors.verticalCenter: parent.verticalCenter
            text: "···"
            font.pixelSize: 6
            font.family: trayIsland.monoFont
            color: trayIsland.zenAsh
        }
    }
}
