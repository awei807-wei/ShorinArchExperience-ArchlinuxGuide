import QtQuick
import Quickshell.Io

Rectangle {
    id: power

    property bool reducedMotion: false
    property color surfaceColor: Qt.rgba(10 / 255, 12 / 255, 13 / 255, 0.86)
    property color hoverColor: Qt.rgba(1, 1, 1, 0.035)
    property color borderColor: Qt.rgba(1, 1, 1, 0.085)
    property color highlightColor: Qt.rgba(1, 1, 1, 0.045)
    property color iconColor: "#6d7376"
    property color iconHoverColor: "#a7abad"

    readonly property bool hovered: pointerArea.containsMouse

    implicitWidth: 38
    implicitHeight: 38
    color: hovered ? hoverColor : surfaceColor
    border.color: borderColor
    border.width: 1
    radius: 3
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: "Power menu"

    function activate() {
        if (!powerProcess.running)
            powerProcess.running = true
    }

    Keys.onReturnPressed: power.activate()
    Keys.onSpacePressed: power.activate()

    Behavior on color {
        enabled: !power.reducedMotion
        ColorAnimation { duration: 130 }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: power.highlightColor
    }

    Canvas {
        id: powerGlyph
        anchors.centerIn: parent
        width: 14
        height: 14

        onPaint: {
            const context = getContext("2d")
            context.clearRect(0, 0, width, height)
            context.strokeStyle = power.hovered ? power.iconHoverColor : power.iconColor
            context.lineWidth = 1.25
            context.lineCap = "round"

            context.beginPath()
            context.moveTo(width / 2, 1.5)
            context.lineTo(width / 2, 7)
            context.stroke()

            context.beginPath()
            context.arc(width / 2, height / 2 + 1, 5,
                -Math.PI * 0.25, Math.PI * 1.25, false)
            context.stroke()
        }

        Connections {
            target: power
            function onHoveredChanged() {
                powerGlyph.requestPaint()
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        color: "transparent"
        border.width: power.activeFocus ? 1 : 0
        border.color: power.iconColor
    }

    Process {
        id: powerProcess
        command: ["wlogout"]
    }

    MouseArea {
        id: pointerArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            power.forceActiveFocus()
            power.activate()
        }
    }
}
