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

    signal triggerPowerMenu()

    property string osIcon: ""
    property color osIconColor: "#1793d1"

    function activate() {
        power.triggerPowerMenu();
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

    // 动态检测 Linux 发行版，默认/Arch 下显示经典 Arch  图标
    Process {
        id: osProcess
        command: ["bash", "-c", "source /etc/os-release 2>/dev/null && echo $ID"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const osId = data.trim().toLowerCase();
                if (osId === "arch") {
                    power.osIcon = "";
                    power.osIconColor = "#1793d1";
                } else if (osId === "nixos") {
                    power.osIcon = "";
                    power.osIconColor = "#5277c3";
                } else if (osId === "manjaro") {
                    power.osIcon = "";
                    power.osIconColor = "#35bf5c";
                } else if (osId === "endeavouros") {
                    power.osIcon = "";
                    power.osIconColor = "#7f71ad";
                } else if (osId === "cachyos") {
                    power.osIcon = "";
                    power.osIconColor = "#00fde8";
                } else if (osId === "artix") {
                    power.osIcon = "";
                    power.osIconColor = "#00fde8";
                } else if (osId === "fedora") {
                    power.osIcon = "";
                    power.osIconColor = "#3c6eb4";
                } else if (osId === "ubuntu") {
                    power.osIcon = "";
                    power.osIconColor = "#e95420";
                } else if (osId === "debian") {
                    power.osIcon = "";
                    power.osIconColor = "#d70a53";
                } else {
                    power.osIcon = "";
                    power.osIconColor = "#1793d1";
                }
            }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: power.radius
        anchors.rightMargin: power.radius
        height: Config.BarTuning.islandTopHighlightHeight
        color: power.highlightColor
    }

    // Arch 图标展示（带悬停发光与动画）
    Text {
        id: iconText
        anchors.centerIn: parent
        text: power.osIcon
        font.pixelSize: 15
        color: power.hovered ? Qt.lighter(power.osIconColor, 1.25) : power.osIconColor

        Behavior on color {
            ColorAnimation { duration: Config.Theme.animFast }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: Config.BarTuning.powerFocusInset
        color: "transparent"
        border.width: power.activeFocus ? 1 : 0
        border.color: power.osIconColor
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
