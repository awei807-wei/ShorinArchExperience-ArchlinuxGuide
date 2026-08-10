import "../config" as Config
import QtQuick
import QtQuick.Controls as Controls

Controls.Button {
    id: root

    property bool expanded: false
    property string selectedLabel: "NO OUTPUT"
    property color accentColor: "#8fb3c5"
    property color textColor: "#d0d0d0"
    property color mutedColor: "#707070"
    property bool reducedMotion: false

    implicitWidth: 34
    implicitHeight: 34
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    padding: 0

    Accessible.name: "音频输出设备"
    Accessible.description: selectedLabel

    contentItem: Text {
        text: root.expanded ? "󰅃" : "󰅀"
        font.family: "Material Design Icons"
        font.pixelSize: 16
        color: root.enabled ? root.accentColor : root.mutedColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: Config.Theme.radiusSmall
        color: root.down || root.expanded
            ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.12)
            : root.hovered
                ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.07)
                : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.035)
        border.width: root.expanded || root.activeFocus ? 1 : 0
        border.color: root.accentColor

        Behavior on color {
            enabled: !root.reducedMotion
            ColorAnimation { duration: Config.Theme.animFast }
        }
    }

    AppToolTip {
        anchors.bottom: parent.top
        anchors.bottomMargin: Config.Theme.spacingTiny
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.selectedLabel
        target: root
        hovered: root.hovered && !root.expanded
    }
}
