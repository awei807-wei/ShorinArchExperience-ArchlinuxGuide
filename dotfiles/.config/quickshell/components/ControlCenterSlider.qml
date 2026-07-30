import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string icon: ""
    property real value: 0
    property bool inactive: false
    property color accentColor: "#8fb3c5"
    property color surfaceColor: "#1c1c1c"
    property color textColor: "#d0d0d0"
    property color mutedColor: "#707070"
    property bool reducedMotion: false

    signal valueRequested(real value)
    signal iconClicked()

    Layout.fillWidth: true
    Layout.preferredHeight: 62

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: root.surfaceColor
        border.color: Qt.rgba(1, 1, 1, 0.05)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 18
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 20
            color: iconMouse.pressed
                ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.12)
                : iconMouse.containsMouse
                    ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.07)
                    : "transparent"

            Text {
                anchors.centerIn: parent
                text: root.icon
                font.family: "Material Design Icons"
                font.pixelSize: 21
                color: root.inactive ? root.mutedColor : root.accentColor
            }

            MouseArea {
                id: iconMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.iconClicked()
            }
        }

        Item {
            id: sliderTrack
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 7
                radius: 4
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.1)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.value / 100))
                    height: parent.height
                    radius: parent.radius
                    color: root.inactive ? root.mutedColor : root.accentColor
                }
            }

            Rectangle {
                id: handle
                x: Math.max(0, Math.min(parent.width - width,
                    parent.width * root.value / 100 - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: sliderMouse.pressed ? 30 : 20
                radius: 9
                color: root.accentColor

                Behavior on height {
                    enabled: !root.reducedMotion
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                id: sliderMouse
                anchors.fill: parent
                preventStealing: true
                cursorShape: Qt.PointingHandCursor

                function requestAt(mouseX) {
                    const nextValue = Math.max(0, Math.min(100, mouseX / width * 100))
                    root.valueRequested(nextValue)
                }

                onPressed: mouse => requestAt(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        requestAt(mouse.x)
                }
            }
        }

        Text {
            Layout.preferredWidth: 42
            text: Math.round(root.value) + "%"
            font.family: "JetBrains Mono"
            font.pixelSize: 12
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignRight
            color: root.textColor
        }
    }
}
