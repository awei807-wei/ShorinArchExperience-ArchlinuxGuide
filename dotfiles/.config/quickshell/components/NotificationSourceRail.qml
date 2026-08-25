import QtQuick
import "../config" as Config

Item {
    id: sourceRail

    property var sources: []
    property string selectedSourceKey: "__all__"
    property var menuWindow: null
    property bool reducedMotion: false
    property color surfaceColor: Config.Theme.surface
    property color hoverColor: Config.Theme.surfaceContainer
    property color outlineColor: Config.Theme.outlineVariant
    property color textColor: Config.Theme.textPrimary
    property color mutedColor: Config.Theme.textMuted
    property color accentColor: Config.Theme.accent
    property color badgeColor: Config.Theme.danger
    property var hoveredSource: null
    property var hoveredSourceItem: null
    property bool tooltipHovered: false
    readonly property var allSource: sources.length > 0 ? sources[0] : null
    readonly property var applicationSources: sources.length > 1
        ? sources.slice(1) : []
    readonly property real hoveredCenterX: {
        if (!hoveredSourceItem)
            return 0
        return hoveredSourceItem.mapToItem(
            sourceRail, hoveredSourceItem.width / 2, 0).x
    }
    readonly property string tooltipText: {
        if (!hoveredSource)
            return ""
        const count = Math.max(0, Number(hoveredSource.count) || 0)
        const lines = [
            String(hoveredSource.label || "Notification"),
            count + (count === 1 ? " notification" : " notifications"),
            "Left click: filter"
        ]
        if (hoveredSource.trayItem && hoveredSource.trayItem.hasMenu)
            lines.push("Right click: app menu")
        return lines.join("\n")
    }

    signal sourceRequested(string key)

    implicitHeight: Config.BarTuning.notificationSourceRailHeight

    function updateHover(source, item, hovered) {
        if (hovered) {
            hoveredSource = source
            hoveredSourceItem = item
            tooltipHovered = true
        } else if (hoveredSourceItem === item) {
            tooltipHovered = false
            hoveredSource = null
            hoveredSourceItem = null
        }
    }

    Row {
        id: railRow

        anchors.fill: parent
        spacing: Config.BarTuning.notificationSourceRailGap

        Rectangle {
            id: allButton

            anchors.verticalCenter: parent.verticalCenter
            width: Config.BarTuning.notificationSourceAllWidth
            height: Config.BarTuning.notificationSourceControlHeight
            radius: Config.Theme.radiusSmall
            color: sourceRail.selectedSourceKey === "__all__"
                ? Qt.rgba(sourceRail.accentColor.r, sourceRail.accentColor.g,
                          sourceRail.accentColor.b, 0.16)
                : (allMouse.containsMouse ? sourceRail.hoverColor : "transparent")
            border.width: 1
            border.color: sourceRail.selectedSourceKey === "__all__"
                ? sourceRail.accentColor
                : (allMouse.containsMouse
                    ? sourceRail.outlineColor : "transparent")
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "All notifications, "
                + String(sourceRail.allSource
                    ? sourceRail.allSource.count : 0)

            Behavior on color {
                enabled: !sourceRail.reducedMotion
                ColorAnimation { duration: Config.Theme.animFast }
            }

            Behavior on border.color {
                enabled: !sourceRail.reducedMotion
                ColorAnimation { duration: Config.Theme.animFast }
            }

            Row {
                anchors.centerIn: parent
                spacing: 7

                Text {
                    text: "ALL"
                    color: sourceRail.textColor
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.7
                }

                Text {
                    text: String(sourceRail.allSource
                        ? sourceRail.allSource.count : 0)
                    color: sourceRail.selectedSourceKey === "__all__"
                        ? sourceRail.accentColor : sourceRail.mutedColor
                    font.family: "JetBrains Mono"
                    font.pixelSize: Config.Theme.fontSmall
                    font.weight: Font.Medium
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: allButton.activeFocus ? 1 : 0
                border.color: sourceRail.textColor
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                        || event.key === Qt.Key_Space) {
                    sourceRail.sourceRequested("__all__")
                    event.accepted = true
                }
            }

            MouseArea {
                id: allMouse

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onEntered: sourceRail.updateHover(
                    sourceRail.allSource, allButton, true)
                onExited: sourceRail.updateHover(
                    sourceRail.allSource, allButton, false)
                onClicked: sourceRail.sourceRequested("__all__")
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 26
            color: sourceRail.outlineColor
        }

        Flickable {
            id: sourceViewport

            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, sourceRail.width
                - Config.BarTuning.notificationSourceAllWidth
                - railRow.spacing * 2 - 1)
            height: Config.BarTuning.notificationSourceSlotSize
            contentWidth: sourceRow.implicitWidth
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentWidth > width
            clip: true

            Row {
                id: sourceRow

                spacing: Config.BarTuning.notificationSourceGap

                Repeater {
                    model: sourceRail.applicationSources

                    NotificationSourceTab {
                        required property var modelData

                        source: modelData
                        menuWindow: sourceRail.menuWindow
                        selected: modelData.key
                            === sourceRail.selectedSourceKey
                        reducedMotion: sourceRail.reducedMotion
                        surfaceColor: sourceRail.surfaceColor
                        hoverColor: sourceRail.hoverColor
                        outlineColor: sourceRail.outlineColor
                        textColor: sourceRail.textColor
                        mutedColor: sourceRail.mutedColor
                        accentColor: sourceRail.accentColor
                        badgeColor: sourceRail.badgeColor
                        onSourceRequested: key =>
                            sourceRail.sourceRequested(key)
                        onHoverChanged: (source, item, hovered) =>
                            sourceRail.updateHover(source, item, hovered)
                    }
                }
            }
        }
    }

    AppToolTip {
        id: sourceTooltip

        x: Math.max(0, Math.min(sourceRail.width - width,
                                sourceRail.hoveredCenterX - width / 2))
        y: sourceRail.height + Config.Theme.spacingTiny
        text: sourceRail.tooltipText
        hovered: sourceRail.tooltipHovered
        delay: 420
    }
}
