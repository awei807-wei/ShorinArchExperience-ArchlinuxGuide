import QtQuick
import "config" as Config

// 右上角锁屏电源与 idle 控制。该组件只负责布局和输入信号，系统命令仍由 shell.qml 执行。
Item {
    id: root

    property real unit: 16
    property bool powerMenuVisible: false
    property bool idleEnabled: true
    property bool idleToggleBusy: false
    property bool reducedMotion: false
    property color textPrimary: Config.Theme.textPrimary
    property color textSecondary: Config.Theme.textSecondary
    property color bgGlass: Qt.rgba(0.078, 0.078, 0.098, 0.72)
    property string iconFontFamily: "JetBrainsMono Nerd Font"

    readonly property real buttonDiameter: root.unit * 2.8
    readonly property real buttonSpacing: root.unit * 0.55
    readonly property real menuGap: root.unit * 0.75
    readonly property Item topButtonsItem: topButtons
    readonly property Item powerButtonItem: powerButton
    readonly property Item idleToggleButtonItem: idleToggleButton
    readonly property Text powerIconItem: powerIcon
    readonly property Text idleIconItem: idleIcon
    readonly property Item powerMenuItem: powerMenu

    signal powerMenuToggleRequested()
    signal idleToggleRequested(bool enabled)
    signal powerActionRequested(string action)

    width: Math.max(topButtons.implicitWidth, powerMenu.width)
    height: topButtons.height + (root.powerMenuVisible ? root.powerMenuItem.implicitHeight + root.menuGap : 0)

    Row {
        id: topButtons
        anchors.top: parent.top
        anchors.right: parent.right
        width: implicitWidth
        height: root.buttonDiameter
        spacing: root.buttonSpacing

        Rectangle {
            id: powerButton
            width: root.buttonDiameter
            height: root.buttonDiameter
            radius: width / 2
            color: powerButtonArea.containsMouse
                ? Qt.rgba(1, 1, 1, 0.1)
                : Qt.rgba(1, 1, 1, 0.05)
            border.color: Qt.rgba(1, 1, 1, 0.1)

            Behavior on color {
                enabled: !root.reducedMotion
                ColorAnimation { duration: Config.Theme.animFast }
            }

            Text {
                id: powerIcon
                anchors.fill: parent
                text: "\uf011"
                color: root.textSecondary
                font.family: root.iconFontFamily
                font.pixelSize: root.unit * 1.2
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
                id: powerButtonArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: function(mouse) {
                    root.powerMenuToggleRequested()
                    mouse.accepted = true
                }
            }
        }

        Rectangle {
            id: idleToggleButton
            width: root.buttonDiameter
            height: root.buttonDiameter
            radius: width / 2
            color: idleToggleArea.containsMouse
                ? Qt.rgba(1, 1, 1, 0.1)
                : Qt.rgba(1, 1, 1, 0.05)
            border.color: Qt.rgba(1, 1, 1, 0.1)
            opacity: root.idleToggleBusy ? 0.66 : 1.0

            Behavior on color {
                enabled: !root.reducedMotion
                ColorAnimation { duration: Config.Theme.animFast }
            }

            Text {
                id: idleIcon
                anchors.fill: parent
                // 保持旧状态语义：idle 开启时显示带斜线图标，关闭时显示普通 eye。
                text: root.idleEnabled ? "\uf070" : "\uf06e"
                color: root.textSecondary
                font.family: root.iconFontFamily
                font.pixelSize: root.unit * 1.05
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                opacity: root.idleEnabled ? 0.72 : 0.98
            }

            MouseArea {
                id: idleToggleArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: !root.idleToggleBusy
                onClicked: root.idleToggleRequested(!root.idleEnabled)
            }
        }
    }

    Rectangle {
        id: powerMenu
        anchors.top: topButtons.bottom
        anchors.topMargin: root.menuGap
        anchors.right: parent.right
        width: Math.max(topButtons.implicitWidth, contentColumn.implicitWidth)
        implicitHeight: contentColumn.height + root.unit * 2
        height: root.powerMenuVisible ? implicitHeight : 0
        radius: Config.Theme.radiusMedium
        clip: true
        color: root.bgGlass
        border.color: Qt.rgba(1, 1, 1, 0.08)
        opacity: root.powerMenuVisible ? 1 : 0
        visible: root.powerMenuVisible || opacity > 0
        enabled: root.powerMenuVisible

        Behavior on opacity {
            enabled: !root.reducedMotion
            NumberAnimation { duration: Config.Theme.animNormal; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            enabled: !root.reducedMotion
            NumberAnimation { duration: Config.Theme.animNormal; easing.type: Easing.OutCubic }
        }

        Column {
            id: contentColumn
            anchors.top: parent.top
            anchors.topMargin: root.unit
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.unit * 0.5

            Repeater {
                model: [
                    { text: "关机", icon: "ⵚ", action: "poweroff" },
                    { text: "休眠", icon: "⯕", action: "suspend" },
                    { text: "重启", icon: "↺", action: "reboot" }
                ]
                delegate: Rectangle {
                    implicitWidth: itemRow.implicitWidth + root.unit * 1.6
                    width: implicitWidth
                    height: root.unit * 1.8
                    radius: Config.Theme.radiusSmall
                    color: itemArea.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.05)
                        : "transparent"

                    Behavior on color {
                        enabled: !root.reducedMotion
                        ColorAnimation { duration: Config.Theme.animFast }
                    }

                    Row {
                        id: itemRow
                        anchors.left: parent.left
                        anchors.leftMargin: root.unit * 0.8
                        anchors.verticalCenter: parent.verticalCenter
                        height: root.unit * 1.5
                        spacing: root.unit * 0.6

                        Text {
                            text: modelData.icon
                            font.pixelSize: root.unit
                            color: root.textSecondary
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: modelData.text
                            font.pixelSize: root.unit * 0.9
                            font.family: "Source Han Sans CN"
                            color: root.textPrimary
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: itemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.powerActionRequested(modelData.action)
                    }
                }
            }
        }
    }
}
