pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../config" as Config

Rectangle {
    id: trayIsland

    property real unit: Config.BarTuning.trayUnit
    property color zenInk: Config.Theme.surface
    property color zenMist: Config.Theme.outline
    property color zenStone: Config.Theme.surfaceContainer
    property color zenAsh: Config.Theme.outlineVariant
    property color zenCloud: Config.Theme.textMuted
    property color zenSnow: Config.Theme.textSecondary
    property color zenDanger: Config.Theme.danger
    property color highlightColor: Config.Theme.outlineVariant
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
    readonly property real itemWidth: Config.BarTuning.trayItemWidth
    readonly property real iconSize: Config.BarTuning.trayIconSize
    readonly property real itemGap: Config.BarTuning.trayItemGap
    readonly property real horizontalPadding: Config.BarTuning.trayHorizontalPadding
    readonly property real expandedContentWidth: (trayCount + 1) * itemWidth
        + Math.max(0, trayCount) * itemGap + horizontalPadding
    readonly property real expandedWidth: Math.max(
        unit * Config.BarTuning.trayExpandedMinUnits, expandedContentWidth)

    signal toggleRequested(real panelWidth)
    signal closeRequested()

    implicitWidth: collapsedSlots === 0 ? Config.BarTuning.trayEmptyWidth
        : collapsedSlots * itemWidth
            + Math.max(0, collapsedSlots - 1) * itemGap
            + horizontalPadding
    implicitHeight: Config.BarTuning.islandHeight
    width: preferredWidth > 0 ? preferredWidth : implicitWidth
    color: zenInk
    border.color: zenMist
    border.width: Config.BarTuning.islandBorderWidth
    radius: Config.Theme.radiusMedium
    clip: false

    onHasCompositeEntryChanged: {
        if (!hasCompositeEntry && expanded)
            closeRequested()
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Config.BarTuning.islandTopHighlightHeight
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
        border.width: Config.BarTuning.islandBorderWidth
        radius: Config.Theme.radiusMedium
        opacity: visible ? 1 : 0

        Behavior on x {
            enabled: !trayIsland.reducedMotion
            NumberAnimation { duration: Config.Theme.animNormal; easing.type: Easing.OutCubic }
        }

        Behavior on width {
            enabled: !trayIsland.reducedMotion
            NumberAnimation { duration: Config.Theme.animNormal; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Config.BarTuning.islandTopHighlightHeight
            color: trayIsland.highlightColor
        }

        Behavior on opacity {
            enabled: !trayIsland.reducedMotion
            NumberAnimation { duration: Config.Theme.animNormal; easing.type: Easing.OutQuad }
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
                    NumberAnimation { duration: Config.Theme.animNormal; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    enabled: !trayIsland.reducedMotion
                    NumberAnimation { duration: Config.Theme.animNormal; easing.type: Easing.OutQuad }
                }

                Rectangle {
                    id: trayItemBackground
                    anchors.centerIn: parent
                    width: trayIsland.iconSize
                    height: trayIsland.iconSize
                    radius: Config.Theme.radiusSmall
                    color: trayItemMouse.containsMouse ? Config.Theme.surfaceContainer : "transparent"
                    border.color: trayItemMouse.containsMouse
                        ? Config.Theme.outline : Config.Theme.outlineVariant
                    border.width: 1

                    Behavior on color {
                        enabled: !trayIsland.reducedMotion
                        ColorAnimation { duration: Config.Theme.animFast }
                    }

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
                NumberAnimation { duration: Config.Theme.animNormal; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                enabled: !trayIsland.reducedMotion
                NumberAnimation { duration: Config.Theme.animNormal; easing.type: Easing.OutQuad }
            }

            Rectangle {
                id: compositeBackground
                anchors.centerIn: parent
                width: trayIsland.iconSize
                height: trayIsland.iconSize
                radius: Config.Theme.radiusSmall
                color: compositeEntry.hovered ? Config.Theme.surfaceContainer : "transparent"
                border.color: compositeEntry.hovered
                    ? Config.Theme.outline : Config.Theme.outlineVariant
                border.width: 1

                Behavior on color {
                    enabled: !trayIsland.reducedMotion
                    ColorAnimation { duration: Config.Theme.animFast }
                }
            }

            Text {
                visible: trayIsland.hiddenTrayCount > 0
                anchors.centerIn: compositeBackground
                text: "+" + trayIsland.hiddenTrayCount
                textFormat: Text.PlainText
                font.pixelSize: Config.BarTuning.trayCompositeFontSize
                font.family: trayIsland.monoFont
                color: trayIsland.zenCloud
            }

            Item {
                visible: trayIsland.hiddenTrayCount === 0 && trayIsland.notificationCount > 0
                anchors.centerIn: compositeBackground
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
                anchors.topMargin: Config.BarTuning.trayBadgeTopOffset
                anchors.rightMargin: Config.BarTuning.trayBadgeRightOffset
                height: Config.BarTuning.trayBadgeHeight
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
                    font.pixelSize: Config.Theme.fontTiny
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
                font.pixelSize: Config.Theme.fontTiny
                font.family: trayIsland.monoFont
                color: collapseButton.hovered ? trayIsland.zenSnow : trayIsland.zenCloud

                Behavior on color {
                    enabled: !trayIsland.reducedMotion
                    ColorAnimation { duration: Config.Theme.animFast }
                }
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
            font.pixelSize: Config.Theme.fontTiny
            font.family: trayIsland.monoFont
            color: trayIsland.zenAsh
        }
    }
}
