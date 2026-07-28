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

    readonly property int horizontalPadding: compact ? 8 : 11
    readonly property int contentGap: compact ? 7 : 10
    readonly property int metaWidth: compact ? 52 : 58
    readonly property int workspaceGap: compact ? 3 : 5

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
                spacing: 3

                Text {
                    text: workspaceStrip.labelText
                    color: workspaceStrip.textDim
                    font.family: workspaceStrip.monoFont
                    font.pixelSize: 6
                    font.letterSpacing: 0.9
                }

                Text {
                    text: workspaceStrip.valueText
                    color: workspaceStrip.textColor
                    font.family: workspaceStrip.monoFont
                    font.pixelSize: 8
                    font.letterSpacing: 0.32
                }

                Text {
                    text: workspaceStrip.subText
                    color: workspaceStrip.textSoft
                    font.family: workspaceStrip.monoFont
                    font.pixelSize: 6
                    font.letterSpacing: 0.36
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
            width: parent.width - workspaceStrip.metaWidth - 1
                - workspaceStrip.contentGap * 2
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

                        width: (workspaceArea.width - workspaceStrip.workspaceGap * 4) / 5
                        height: parent.height
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: "Workspace " + workspaceNumber

                        Keys.onReturnPressed: workspaceStrip.workspaceRequested(workspaceNumber)
                        Keys.onSpacePressed: workspaceStrip.workspaceRequested(workspaceNumber)

                        Text {
                            anchors.top: parent.top
                            anchors.topMargin: 7
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: workspaceStrip.pad2(workspaceButton.workspaceNumber)
                            color: workspaceButton.active ? workspaceStrip.textColor
                                : (workspaceButton.hovered || workspaceButton.occupied
                                    ? workspaceStrip.textSoft : workspaceStrip.textDim)
                            font.family: workspaceStrip.monoFont
                            font.pixelSize: 6
                            font.letterSpacing: 0

                            Behavior on color {
                                enabled: !workspaceStrip.reducedMotion
                                ColorAnimation { duration: 140 }
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: workspaceButton.active ? 22 : 12
                            height: 2
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
                            width: 8
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
