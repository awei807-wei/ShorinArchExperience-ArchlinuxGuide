// 右岛托盘：3 个直显应用槽位 + 1 个独立复合入口。
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Rectangle {
    id: trayIsland

    property real unit: 13.6
    property color zenInk: "#141414"
    property color zenMist: "#2a2a2a"
    property color zenStone: "#1f1f1f"
    property color zenAsh: "#3a3a3a"
    property color zenCloud: "#8a8a8a"
    property color zenSnow: "#cacaca"
    property color zenDanger: "#9a5555"
    property var panelWindow: null
    property var trayItems: SystemTray.items
    property int directIconLimit: 3
    property int notificationCount: 0
    property bool expanded: false

    readonly property int trayCount: Array.isArray(trayItems)
        ? trayItems.length
        : (trayItems?.values ? trayItems.values.length : (trayItems?.count ?? 0))
    readonly property int hiddenTrayCount: Math.max(0, trayCount - directIconLimit)
    readonly property bool hasCompositeEntry: hiddenTrayCount > 0 || notificationCount > 0
    readonly property int collapsedSlots: Math.min(trayCount, directIconLimit)
        + (hasCompositeEntry ? 1 : 0)
    readonly property real itemWidth: unit * 1.2
    readonly property real itemGap: unit * 0.4
    readonly property real horizontalPadding: unit * 1.2
    readonly property real expandedContentWidth: (trayCount + 1) * itemWidth
        + Math.max(0, trayCount) * itemGap + horizontalPadding
    readonly property real expandedWidth: Math.max(unit * 18, expandedContentWidth)

    signal toggleRequested(real panelWidth)
    signal closeRequested()

    implicitWidth: {
        if (collapsedSlots === 0)
            return unit * 2.5
        return collapsedSlots * itemWidth
            + Math.max(0, collapsedSlots - 1) * itemGap
            + horizontalPadding
    }
    width: implicitWidth
    height: parent?.height ?? unit * 2
    color: zenInk
    border.color: zenMist
    border.width: 1
    radius: 2
    clip: false

    onHasCompositeEntryChanged: {
        if (!hasCompositeEntry && expanded)
            closeRequested()
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
        radius: 2
        opacity: visible ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
        }
    }

    Row {
        id: trayRow
        z: 1
        anchors.right: parent.right
        anchors.rightMargin: trayIsland.unit * 0.6
        anchors.verticalCenter: parent.verticalCenter
        spacing: trayIsland.itemGap

        Repeater {
            model: trayIsland.trayItems

            Item {
                id: trayItemContainer
                visible: trayIsland.expanded || index < trayIsland.directIconLimit
                width: visible ? trayIsland.itemWidth : 0
                height: trayIsland.itemWidth
                opacity: visible ? 1 : 0

                Behavior on width {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
                }

                Rectangle {
                    id: trayItemBackground
                    anchors.fill: parent
                    color: trayItemMouse.containsMouse ? trayIsland.zenStone : "transparent"
                    radius: 2

                    Image {
                        anchors.centerIn: parent
                        width: trayIsland.unit * 0.9
                        height: width
                        source: modelData.icon
                        sourceSize.width: width
                        sourceSize.height: height
                    }
                }

                MouseArea {
                    id: trayItemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            if (modelData.hasMenu)
                                menuAnchor.open()
                        } else {
                            modelData.activate()
                            trayIsland.closeRequested()
                        }
                    }
                }

                QsMenuAnchor {
                    id: menuAnchor
                    menu: modelData.menu
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

            Behavior on width {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
            }

            Rectangle {
                anchors.fill: parent
                radius: 2
                color: compositeEntry.hovered ? trayIsland.zenStone : "transparent"
                border.color: compositeEntry.hovered ? trayIsland.zenAsh : "transparent"
            }

            Text {
                visible: trayIsland.hiddenTrayCount > 0
                anchors.centerIn: parent
                text: "+" + trayIsland.hiddenTrayCount
                textFormat: Text.PlainText
                font.pixelSize: trayIsland.unit * 0.4
                font.family: "JetBrainsMono Nerd Font"
                color: trayIsland.zenCloud
            }

            Item {
                visible: trayIsland.hiddenTrayCount === 0 && trayIsland.notificationCount > 0
                anchors.centerIn: parent
                width: trayIsland.unit * 0.58
                height: trayIsland.unit * 0.62

                Rectangle {
                    x: trayIsland.unit * 0.08
                    y: trayIsland.unit * 0.03
                    width: trayIsland.unit * 0.5
                    height: trayIsland.unit * 0.43
                    color: "transparent"
                    border.color: trayIsland.zenCloud
                    border.width: 1
                    radius: 1
                }
                Rectangle {
                    x: 0
                    y: trayIsland.unit * 0.14
                    width: trayIsland.unit * 0.5
                    height: trayIsland.unit * 0.43
                    color: trayIsland.zenInk
                    border.color: trayIsland.zenCloud
                    border.width: 1
                    radius: 1
                }
            }

            Rectangle {
                visible: trayIsland.notificationCount > 0
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: -trayIsland.unit * 0.12
                anchors.rightMargin: -trayIsland.unit * 0.16
                height: trayIsland.unit * 0.58
                width: Math.max(height, notificationBadgeText.implicitWidth + trayIsland.unit * 0.28)
                radius: height / 2
                color: trayIsland.zenDanger
                border.color: trayIsland.zenInk
                border.width: 1

                Text {
                    id: notificationBadgeText
                    anchors.centerIn: parent
                    text: trayIsland.notificationCount > 99 ? "99+" : String(trayIsland.notificationCount)
                    textFormat: Text.PlainText
                    font.pixelSize: trayIsland.unit * 0.26
                    font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                    color: trayIsland.zenSnow
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: compositeEntry.hovered = true
                onExited: compositeEntry.hovered = false
                onClicked: trayIsland.toggleRequested(trayIsland.expandedWidth)
            }
        }

        Item {
            id: collapseButton
            property bool hovered: false
            visible: trayIsland.expanded
            width: visible ? trayIsland.itemWidth : 0
            height: trayIsland.itemWidth
            opacity: visible ? 1 : 0

            Text {
                anchors.centerIn: parent
                text: "«"
                font.pixelSize: trayIsland.unit * 0.45
                font.family: "JetBrainsMono Nerd Font"
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
            font.pixelSize: trayIsland.unit * 0.4
            font.family: "JetBrainsMono Nerd Font"
            color: trayIsland.zenAsh
        }
    }
}
