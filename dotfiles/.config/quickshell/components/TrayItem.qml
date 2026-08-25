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
    // 延迟左键单击，给双击留出系统双击间隔；这样双击不会先触发一次 activate。
    readonly property int clickDisambiguationInterval: Qt.styleHints.mouseDoubleClickInterval
    property bool suppressNextSingleClick: false

    signal closeRequested()
    signal identityChanged()
    signal focusRequested(var trayItem)

    function scheduleSingleClick() {
        if (suppressNextSingleClick) {
            suppressNextSingleClick = false
            doubleClickGuardReset.stop()
            return
        }
        delayedSingleClick.restart()
    }

    function cancelPendingSingleClick() {
        delayedSingleClick.stop()
    }

    function openTrayMenu() {
        cancelPendingSingleClick()
        suppressNextSingleClick = false
        doubleClickGuardReset.stop()
        if (trayItem && trayItem.hasMenu)
            menuAnchor.open()
    }

    function focusTrayItemOnDoubleClick() {
        cancelPendingSingleClick()
        suppressNextSingleClick = true
        doubleClickGuardReset.restart()
        focusRequested(trayItem)
        closeRequested()
    }

    function activateTrayItem() {
        cancelPendingSingleClick()
        if (trayItem && trayItem.activate) {
            trayItem.activate()
            closeRequested()
        }
    }

    function cancelAllClickTimers() {
        cancelPendingSingleClick()
        suppressNextSingleClick = false
        doubleClickGuardReset.stop()
    }

    visible: shown
    width: visible ? itemWidth : 0
    height: itemWidth
    opacity: visible ? 1 : 0
    // visible=false 已会把条目排除出焦点链；保持该值稳定可避免
    // 展开/收起时在仍持有焦点的同一帧写入 false。
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: {
        const title = trayItem && trayItem.title ? trayItem.title : "System tray item"
        return notificationCount > 0
            ? title + ", " + notificationCount + " notifications" : title
    }

    onVisibleChanged: {
        if (!visible)
            cancelAllClickTimers()
    }

    Component.onDestruction: cancelAllClickTimers()

    Keys.onReturnPressed: activateTrayItem()
    Keys.onSpacePressed: activateTrayItem()

    Timer {
        id: delayedSingleClick
        interval: root.clickDisambiguationInterval
        repeat: false
        onTriggered: root.activateTrayItem()
    }

    Timer {
        id: doubleClickGuardReset
        interval: root.clickDisambiguationInterval
        repeat: false
        onTriggered: root.suppressNextSingleClick = false
    }

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
                root.openTrayMenu()
            } else {
                root.scheduleSingleClick()
            }
        }

        onDoubleClicked: mouse => {
            if (mouse.button !== Qt.LeftButton)
                return

            root.focusTrayItemOnDoubleClick()
        }
    }

    QsMenuAnchor {
        id: menuAnchor
        menu: root.trayItem ? root.trayItem.menu : null
        anchor.window: root.panelWindow
        anchor.item: background
    }
}
