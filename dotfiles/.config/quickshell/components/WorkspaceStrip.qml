pragma ComponentBehavior: Bound

import QtQuick
import "../config" as Config

Item {
    id: workspaceStrip

    property string labelText: "RANGE"
    property string valueText: "01–05"
    property string subText: "WS 01"
    property int activeWorkspace: 1
    property int rangeStart: 1
    property var occupiedWorkspaces: []
    property bool compact: false
    property bool reducedMotion: false
    property color textColor: Config.Theme.textPrimary
    property color textSoft: Config.Theme.textSecondary
    property color textDim: Config.Theme.textMuted
    property color lineColor: Config.Theme.outline
    property color accentColor: Config.Theme.accent
    property color occupiedColor: Config.Theme.textMuted
    property color emptyColor: Config.Theme.surfaceContainer
    property string monoFont: "JetBrains Mono"

    readonly property int horizontalPadding: compact
        ? Config.BarTuning.contextCompactHorizontalPadding
        : Config.BarTuning.contextHorizontalPadding
    readonly property int contentGap: compact
        ? Config.BarTuning.contextCompactContentGap : Config.BarTuning.contextContentGap
    readonly property int metaWidth: compact
        ? Config.BarTuning.contextCompactMetaWidth : Config.BarTuning.contextMetaWidth
    readonly property int workspaceGap: compact
        ? Config.BarTuning.workspaceCompactGap : Config.BarTuning.workspaceGap

    signal workspaceRequested(int workspace)

    function isOccupied(workspace) {
        return occupiedWorkspaces.indexOf(workspace) !== -1
    }

    function pad2(value) {
        return String(value).padStart(2, "0")
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: workspaceStrip.horizontalPadding
        anchors.rightMargin: workspaceStrip.horizontalPadding
        spacing: workspaceStrip.contentGap

        Item {
            width: workspaceStrip.metaWidth
            height: parent.height

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: Config.BarTuning.contextMetaSpacing

                Text {
                    width: parent.width
                    text: workspaceStrip.labelText
                    elide: Text.ElideRight
                    color: workspaceStrip.textDim
                    font.family: workspaceStrip.monoFont
                    font.pixelSize: Config.Theme.fontTiny
                    font.letterSpacing: 0.7
                }

                Text {
                    width: parent.width
                    text: workspaceStrip.valueText
                    elide: Text.ElideRight
                    color: workspaceStrip.textColor
                    font.family: workspaceStrip.monoFont
                    font.pixelSize: Config.Theme.fontTiny
                    font.letterSpacing: 0.2
                }

                Text {
                    width: parent.width
                    text: workspaceStrip.subText
                    elide: Text.ElideRight
                    color: workspaceStrip.textSoft
                    font.family: workspaceStrip.monoFont
                    font.pixelSize: Config.Theme.fontTiny
                    font.letterSpacing: 0.25
                }
            }
        }

        Rectangle {
            width: 1
            height: Config.BarTuning.contextDividerHeight
            anchors.verticalCenter: parent.verticalCenter
            color: workspaceStrip.lineColor
        }

        Item {
            id: workspaceArea
            readonly property real buttonWidth: Math.max(0,
                (width - workspaceStrip.workspaceGap * 4) / 5)

            width: Math.max(0, parent.width - workspaceStrip.metaWidth - 1
                - workspaceStrip.contentGap * 2)
            height: parent.height

            Row {
                anchors.fill: parent
                spacing: workspaceStrip.workspaceGap

                Repeater {
                    model: 5

                    Item {
                        id: workspaceButton

                        required property int index
                        readonly property int workspaceNumber: workspaceStrip.rangeStart + index
                        readonly property bool active: workspaceNumber === workspaceStrip.activeWorkspace
                        readonly property bool occupied: workspaceStrip.isOccupied(workspaceNumber)
                        readonly property bool hovered: pointerArea.containsMouse

                        width: workspaceArea.buttonWidth
                        height: parent.height
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: "Workspace " + workspaceNumber

                        Keys.onReturnPressed: workspaceStrip.workspaceRequested(workspaceNumber)
                        Keys.onSpacePressed: workspaceStrip.workspaceRequested(workspaceNumber)

                        Text {
                            anchors.top: parent.top
                            anchors.topMargin: Config.BarTuning.workspaceNumberTop
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: workspaceStrip.pad2(workspaceButton.workspaceNumber)
                            color: workspaceButton.active ? workspaceStrip.textColor
                                : (workspaceButton.hovered || workspaceButton.occupied
                                    ? workspaceStrip.textSoft : workspaceStrip.textDim)
                            font.family: workspaceStrip.monoFont
                            font.pixelSize: Config.BarTuning.workspaceNumberFontSize
                            font.letterSpacing: 0

                            Behavior on color {
                                enabled: !workspaceStrip.reducedMotion
                                ColorAnimation { duration: Config.Theme.animFast }
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Config.BarTuning.workspaceIndicatorBottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(workspaceButton.width,
                                workspaceButton.active
                                    ? (workspaceStrip.compact
                                        ? Config.BarTuning.workspaceCompactActiveWidth
                                        : Config.BarTuning.workspaceActiveWidth)
                                    : (workspaceStrip.compact
                                        ? Config.BarTuning.workspaceCompactInactiveWidth
                                        : Config.BarTuning.workspaceInactiveWidth))
                            height: Config.BarTuning.workspaceIndicatorHeight
                            color: workspaceButton.active ? workspaceStrip.accentColor
                                : (workspaceButton.occupied
                                    ? workspaceStrip.occupiedColor : workspaceStrip.emptyColor)

                            Behavior on width {
                                enabled: !workspaceStrip.reducedMotion
                                NumberAnimation { duration: Config.Theme.animFast; easing.type: Easing.OutCubic }
                            }
                            Behavior on color {
                                enabled: !workspaceStrip.reducedMotion
                                ColorAnimation { duration: Config.Theme.animFast }
                            }
                        }

                        Rectangle {
                            visible: workspaceButton.activeFocus
                            anchors.top: parent.top
                            anchors.topMargin: Config.BarTuning.workspaceFocusTop
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(Config.BarTuning.workspaceFocusWidth, workspaceButton.width)
                            height: Config.BarTuning.islandTopHighlightHeight
                            color: workspaceStrip.textDim
                        }

                        MouseArea {
                            id: pointerArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                workspaceButton.forceActiveFocus()
                                workspaceStrip.workspaceRequested(workspaceButton.workspaceNumber)
                            }
                        }
                    }
                }
            }
        }
    }
}
