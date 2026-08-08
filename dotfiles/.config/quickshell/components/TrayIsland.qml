pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "../config" as Config
import "TrayNotificationModel.js" as TrayModel

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
    property var notificationSourceCounts: []
    property bool expanded: false
    property bool reducedMotion: false
    // QAbstractItemModel/UntypedObjectModel 保持同一个对象引用，单靠
    // `trayItems` 绑定不会在注册/注销时重算排序；该版本号显式驱动重排。
    property int modelRevision: 0

    function notificationCountsForItems(items, sources) {
        return TrayModel.notificationCountsForItems(items, sources)
    }

    function sortedItems(items, sources) {
        return TrayModel.sortedItems(items, sources)
    }

    function notificationCountForItem(item) {
        const items = TrayModel.itemArray(trayItems)
        const index = items.indexOf(item)
        if (index < 0)
            return 0
        return notificationCountsForItems(items, notificationSourceCounts)[index]
    }

    function badgeText(count) {
        return count > 99 ? "99+" : String(count)
    }

    readonly property var orderedTrayItems: {
        // 读取 revision 建立 QML 依赖，确保 SystemTray 模型变更后生成新数组。
        const revision = modelRevision
        return TrayModel.sortedItems(trayItems, notificationSourceCounts)
    }

    readonly property int trayCount: {
        return orderedTrayItems.length
    }
    readonly property int hiddenTrayCount: Math.max(0, trayCount - directIconLimit)
    readonly property bool hasCompositeEntry: hiddenTrayCount > 0 || notificationCount > 0
    readonly property int collapsedSlots: Math.max(1,
        Math.min(trayCount, directIconLimit) + (hasCompositeEntry ? 1 : 0))
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

    function focusTrayItem(item) {
        if (!item || focusProcess.running)
            return

        focusProcess.command = [
            "bash",
            Quickshell.shellPath("scripts/focus-tray-item.sh"),
            item.id || item.trayId || "",
            item.title || "",
            item.tooltipTitle || ""
        ]
        focusProcess.running = true
    }

    // 所有托盘 delegate 共用一个短生命周期进程，避免每个图标常驻 Process。
    Process {
        id: focusProcess
        command: ["true"]
    }

    implicitWidth: collapsedSlots * itemWidth
        + Math.max(0, collapsedSlots - 1) * itemGap
        + horizontalPadding
    implicitHeight: Config.BarTuning.islandHeight
    width: implicitWidth
    color: zenInk
    border.color: zenMist
    border.width: Config.BarTuning.islandBorderWidth
    radius: Config.Theme.radiusMedium
    clip: false

    onHasCompositeEntryChanged: {
        if (!hasCompositeEntry && expanded)
            closeRequested()
    }

    Connections {
        // SystemTray.items 是稳定的 UntypedObjectModel 引用；监听其内容
        // 变化，而不是只监听 trayItems 属性本身。
        target: SystemTray.items
        ignoreUnknownSignals: true

        function onValuesChanged() {
            trayIsland.modelRevision += 1
        }

        function onObjectInsertedPost() {
            trayIsland.modelRevision += 1
        }

        function onObjectRemovedPost() {
            trayIsland.modelRevision += 1
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        // 水平内缩一个圆角半径，避免直角高亮条戳出圆角轮廓（clip: false 时必须内缩）
        anchors.leftMargin: trayIsland.radius
        anchors.rightMargin: trayIsland.radius
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
            // 水平内缩一个圆角半径，避免直角高亮条戳出圆角轮廓
            anchors.leftMargin: expandedSurface.radius
            anchors.rightMargin: expandedSurface.radius
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
            model: trayIsland.orderedTrayItems

            TrayItem {
                required property int index
                required property var modelData
                trayItem: modelData
                shown: trayIsland.expanded || index < trayIsland.directIconLimit
                itemWidth: trayIsland.itemWidth
                iconSize: trayIsland.iconSize
                notificationCount: trayIsland.notificationCountForItem(modelData)
                panelWindow: trayIsland.panelWindow
                reducedMotion: trayIsland.reducedMotion
                surfaceColor: trayIsland.zenInk
                textColor: trayIsland.zenCloud
                badgeColor: trayIsland.zenDanger
                badgeTextColor: trayIsland.zenSnow
                monoFont: trayIsland.monoFont
                onIdentityChanged: trayIsland.modelRevision += 1
                onCloseRequested: trayIsland.closeRequested()
                onFocusRequested: item => trayIsland.focusTrayItem(item)
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
                    text: trayIsland.badgeText(trayIsland.notificationCount)
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
