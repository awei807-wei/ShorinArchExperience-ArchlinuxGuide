pragma ComponentBehavior: Bound

import QtQuick

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
    property color textColor: "#e7e9ea"
    property color textSoft: "#a7abad"
    property color textDim: "#6d7376"
    property color lineColor: Qt.rgba(1, 1, 1, 0.10)
    property color accentColor: "#8fb3c5"
    property color occupiedColor: "#747b7f"
    property color emptyColor: "#3c4143"
    property string monoFont: "JetBrains Mono"

    readonly property int horizontalPadding: compact ? 7 : 9
    readonly property int contentGap: compact ? 5 : 6
    readonly property int metaWidth: compact ? 42 : 46
    readonly property int workspaceGap: compact ? 2 : 3

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
                spacing: 1

                Text {
                    width: parent.width
                    text: workspaceStrip.labelText
                    elide: Text.ElideRight
                    color: workspaceStrip.textDim
                    font.family: workspaceStrip.monoFont
                    font.pixelSize: 7
                    font.letterSpacing: 0.7
                }

                Text {
                    width: parent.width
                    text: workspaceStrip.valueText
                    elide: Text.ElideRight
                    color: workspaceStrip.textColor
                    font.family: workspaceStrip.monoFont
                    font.pixelSize: 9
                    font.letterSpacing: 0.2
                }

                Text {
                    width: parent.width
                    text: workspaceStrip.subText
                    elide: Text.ElideRight
                    color: workspaceStrip.textSoft
                    font.family: workspaceStrip.monoFont
                    font.pixelSize: 7
                    font.letterSpacing: 0.25
                }
            }
        }

        Rectangle {
            width: 1
            height: 18
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
                            anchors.topMargin: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: workspaceStrip.pad2(workspaceButton.workspaceNumber)
                            color: workspaceButton.active ? workspaceStrip.textColor
                                : (workspaceButton.hovered || workspaceButton.occupied
                                    ? workspaceStrip.textSoft : workspaceStrip.textDim)
                            font.family: workspaceStrip.monoFont
                            font.pixelSize: 7
                            font.letterSpacing: 0

                            Behavior on color {
                                enabled: !workspaceStrip.reducedMotion
                                ColorAnimation { duration: 140 }
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(workspaceButton.width,
                                workspaceButton.active
                                    ? (workspaceStrip.compact ? 20 : 22)
                                    : (workspaceStrip.compact ? 12 : 14))
                            height: 3
                            color: workspaceButton.active ? workspaceStrip.accentColor
                                : (workspaceButton.occupied
                                    ? workspaceStrip.occupiedColor : workspaceStrip.emptyColor)

                            Behavior on width {
                                enabled: !workspaceStrip.reducedMotion
                                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                            }
                            Behavior on color {
                                enabled: !workspaceStrip.reducedMotion
                                ColorAnimation { duration: 140 }
                            }
                        }

                        Rectangle {
                            visible: workspaceButton.activeFocus
                            anchors.top: parent.top
                            anchors.topMargin: 3
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(8, workspaceButton.width)
                            height: 1
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
