import "../config" as Config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property int cpuPercent: 0
    property int memoryPercent: 0
    property int diskPercent: 0
    property color surfaceColor: "#1c1c1c"
    property color textColor: "#d0d0d0"
    property color mutedColor: "#707070"
    property color accentColor: "#8fb3c5"

    Layout.fillWidth: true
    Layout.preferredHeight: 98

    Rectangle {
        anchors.fill: parent
        radius: Config.Theme.radiusMedium
        color: root.surfaceColor
        border.color: Config.Theme.outlineVariant
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 0

        StatItem { label: "CPU"; value: root.cpuPercent }
        Divider {}
        StatItem { label: "RAM"; value: root.memoryPercent }
        Divider {}
        StatItem { label: "DISK"; value: root.diskPercent }
    }

    component Divider: Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 44
        color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.08)
    }

    component StatItem: Item {
        id: stat
        required property string label
        required property int value
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 0

        Column {
            anchors.centerIn: parent
            width: 72
            spacing: 4

            Text {
                width: parent.width
                text: stat.label
                horizontalAlignment: Text.AlignHCenter
                font.family: "JetBrains Mono"
                font.pixelSize: Config.Theme.fontSmall
                font.letterSpacing: 1
                color: root.mutedColor
            }

            Text {
                width: parent.width
                text: Math.max(0, Math.min(100, stat.value)) + "%"
                horizontalAlignment: Text.AlignHCenter
                font.family: "JetBrains Mono"
                font.pixelSize: 24
                font.weight: Font.Black
                color: root.textColor
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 38
                height: 3
                radius: 2
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.1)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, stat.value / 100))
                    height: parent.height
                    radius: parent.radius
                    color: stat.value >= 85 ? Config.Theme.danger : root.accentColor
                }
            }
        }
    }
}
