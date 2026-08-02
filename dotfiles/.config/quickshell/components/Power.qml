import "../config" as Config
import QtQuick
import Quickshell.Io

Rectangle {
    id: power

    property bool reducedMotion: false
    property color surfaceColor: Config.Theme.surface
    property color hoverColor: Config.Theme.surfaceContainer
    property color borderColor: Config.Theme.outline
    property color highlightColor: Config.Theme.outlineVariant
    property color iconColor: Config.Theme.textMuted
    property color iconHoverColor: Config.Theme.textSecondary
    readonly property bool hovered: pointerArea.containsMouse

    function activate() {
        if (!powerProcess.running)
            powerProcess.running = true;

    }

    implicitWidth: Config.BarTuning.powerIslandWidth
    implicitHeight: Config.BarTuning.islandHeight
    color: hovered ? hoverColor : surfaceColor
    border.color: borderColor
    border.width: Config.BarTuning.islandBorderWidth
    radius: Config.Theme.radiusMedium
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: "Power menu"
    Keys.onReturnPressed: power.activate()
    Keys.onSpacePressed: power.activate()

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Config.BarTuning.islandTopHighlightHeight
        color: power.highlightColor
    }

    Canvas {
        id: powerGlyph

        anchors.centerIn: parent
        width: Config.BarTuning.powerGlyphSize
        height: Config.BarTuning.powerGlyphSize
        onPaint: {
            const context = getContext("2d");
            context.clearRect(0, 0, width, height);
            context.strokeStyle = power.hovered ? power.iconHoverColor : power.iconColor;
            context.lineWidth = Config.BarTuning.powerGlyphStrokeWidth;
            context.lineCap = "round";
            context.beginPath();
            context.moveTo(width / 2, 1.5);
            context.lineTo(width / 2, 7);
            context.stroke();
            context.beginPath();
            context.arc(width / 2, height / 2 + 1, 5, -Math.PI * 0.25, Math.PI * 1.25, false);
            context.stroke();
        }

        Connections {
            function onHoveredChanged() {
                powerGlyph.requestPaint();
            }

            target: power
        }

    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: Config.BarTuning.powerFocusInset
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
            power.forceActiveFocus();
            power.activate();
        }
    }

    Behavior on color {
        enabled: !power.reducedMotion

        ColorAnimation {
            duration: Config.Theme.animFast
        }

    }

}
