import QtQuick
import QtQuick.Layouts
import "../config" as Config

Rectangle {
    id: root

    property string icon: ""
    property string toolTip: ""
    property bool danger: false
    property bool emphasized: false
    property color accentColor: "#8fb3c5"
    property color elevatedColor: "#252525"
    property color surfaceColor: "#1c1c1c"
    property color textColor: "#d0d0d0"
    property color dangerColor: Config.Theme.danger
    property bool reducedMotion: false
    signal clicked()

    Layout.preferredWidth: emphasized ? 48 : 40
    Layout.preferredHeight: width
    radius: width / 2
    color: emphasized ? root.accentColor
        : buttonMouse.pressed ? root.elevatedColor
        : buttonMouse.containsMouse ? root.surfaceColor : "transparent"

    Behavior on color {
        enabled: !root.reducedMotion
        ColorAnimation { duration: Config.Theme.animFast }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        font.family: "Material Design Icons"
        font.pixelSize: root.emphasized ? 24 : 20
        color: root.emphasized ? Config.Theme.surface
            : root.danger ? root.dangerColor : root.textColor
    }

    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    AppToolTip {
        anchors.top: parent.bottom
        anchors.topMargin: Config.Theme.spacingTiny
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.toolTip
        target: buttonMouse
    }
}
