import "../config" as Config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string icon: ""
    property string label: ""
    property string subLabel: ""
    property string toolTip: ""
    property bool active: false
    property bool interactive: true
    property color activeColor: "#8fb3c5"
    property color surfaceColor: "#1c1c1c"
    property color textColor: "#d0d0d0"
    property color mutedColor: "#707070"
    property bool reducedMotion: false

    signal clicked()

    Layout.fillWidth: true
    Layout.preferredHeight: 72
    opacity: root.interactive || root.active ? 1 : 0.48
    scale: mouseArea.pressed ? 0.97 : 1

    Behavior on scale {
        enabled: !root.reducedMotion
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.fill: parent
        radius: Config.Theme.radiusMedium
        color: root.active
            ? Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.18)
            : root.surfaceColor
        border.color: root.active
            ? Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.48)
            : Config.Theme.outlineVariant

        Behavior on color {
            enabled: !root.reducedMotion
            ColorAnimation { duration: Config.Theme.animFast }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Config.Theme.radiusMedium
        color: root.textColor
        opacity: mouseArea.pressed ? 0.1 : mouseArea.containsMouse ? 0.055 : 0

        Behavior on opacity {
            enabled: !root.reducedMotion
            NumberAnimation { duration: Config.Theme.animFast }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
            radius: root.active ? Config.Theme.radiusMedium : 21
            color: root.active
                ? root.activeColor
                : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.07)

            Behavior on color {
                enabled: !root.reducedMotion
                ColorAnimation { duration: Config.Theme.animFast }
            }

            Behavior on radius {
                enabled: !root.reducedMotion
                NumberAnimation { duration: Config.Theme.animFast }
            }

            Text {
                anchors.centerIn: parent
                text: root.icon
                font.family: "Material Design Icons"
                font.pixelSize: 22
                color: root.active ? Config.Theme.surface : root.textColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.label
                font.family: "JetBrains Mono"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: root.textColor
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.subLabel
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                color: root.active ? root.textColor : root.mutedColor
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.interactive
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    AppToolTip {
        anchors.bottom: parent.top
        anchors.bottomMargin: Config.Theme.spacingTiny
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.toolTip.length > 0 ? root.toolTip : root.label
        target: mouseArea
        enabled: root.interactive
    }
}
