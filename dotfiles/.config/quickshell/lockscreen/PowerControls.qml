import QtQuick
import "config" as Config

// 右上角锁屏操作胶囊。组件只负责布局和输入信号，系统命令仍由 shell.qml 执行。
Item {
    id: root

    property real unit: 16
    property bool powerMenuVisible: false
    property bool idleEnabled: true
    property bool idleToggleBusy: false
    property bool reducedMotion: false
    property color accent: Config.Theme.accent
    property color textPrimary: Config.Theme.textPrimary
    property color textSecondary: Config.Theme.textSecondary
    property color bgGlass: Qt.rgba(0.078, 0.078, 0.098, 0.72)

    readonly property real railWidth: 96
    readonly property real railHeight: 44
    readonly property real controlWidth: 42
    readonly property real controlHeight: 40
    readonly property real iconSize: 18
    readonly property real dividerHeight: 20
    readonly property real menuGap: 12
    readonly property Item topButtonsItem: topControlRail
    readonly property Item powerButtonItem: powerButton
    readonly property Item idleToggleButtonItem: idleToggleButton
    readonly property LockGlyph powerIconItem: powerIcon
    readonly property LockGlyph idleIconItem: idleIcon
    readonly property Item powerMenuItem: powerMenu

    signal powerMenuToggleRequested()
    signal idleToggleRequested(bool enabled)
    signal powerActionRequested(string action)

    width: Math.max(topControlRail.width, powerMenu.width)
    height: topControlRail.height
        + (root.powerMenuVisible ? powerMenu.implicitHeight + root.menuGap : 0)

    Rectangle {
        id: topControlRail

        anchors.top: parent.top
        anchors.right: parent.right
        width: root.railWidth
        height: root.railHeight
        radius: height / 2
        color: Qt.rgba(root.bgGlass.r, root.bgGlass.g, root.bgGlass.b, 0.62)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)

        Row {
            anchors.centerIn: parent
            spacing: 5

            Item {
                id: powerButton

                width: root.controlWidth
                height: root.controlHeight
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "电源菜单"

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return
                            || event.key === Qt.Key_Enter
                            || event.key === Qt.Key_Space) {
                        root.powerMenuToggleRequested()
                        event.accepted = true
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: width / 2
                    color: powerHover.hovered
                        ? Qt.rgba(1, 1, 1, 0.09) : "transparent"
                    border.width: powerButton.activeFocus ? 1 : 0
                    border.color: root.textSecondary

                    Behavior on color {
                        enabled: !root.reducedMotion
                        ColorAnimation { duration: Config.Theme.animFast }
                    }
                }

                LockGlyph {
                    id: powerIcon

                    anchors.centerIn: parent
                    width: root.iconSize
                    height: root.iconSize
                    name: "power"
                    iconColor: root.textSecondary
                }

                HoverHandler {
                    id: powerHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        powerButton.forceActiveFocus()
                        root.powerMenuToggleRequested()
                    }
                }
            }

            Rectangle {
                width: 1
                height: root.dividerHeight
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.10)
            }

            Item {
                id: idleToggleButton

                width: root.controlWidth
                height: root.controlHeight
                enabled: !root.idleToggleBusy
                opacity: root.idleToggleBusy ? 0.56 : 1
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: root.idleEnabled
                    ? "关闭自动息屏" : "开启自动息屏"

                Behavior on opacity {
                    enabled: !root.reducedMotion
                    NumberAnimation { duration: Config.Theme.animFast }
                }

                Keys.onPressed: event => {
                    if (idleToggleButton.enabled
                            && (event.key === Qt.Key_Return
                                || event.key === Qt.Key_Enter
                                || event.key === Qt.Key_Space)) {
                        root.idleToggleRequested(!root.idleEnabled)
                        event.accepted = true
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: width / 2
                    color: idleHover.hovered
                        ? Qt.rgba(1, 1, 1, 0.09) : "transparent"
                    border.width: idleToggleButton.activeFocus ? 1 : 0
                    border.color: root.idleEnabled
                        ? root.textSecondary : root.accent

                    Behavior on color {
                        enabled: !root.reducedMotion
                        ColorAnimation { duration: Config.Theme.animFast }
                    }
                }

                LockGlyph {
                    id: idleIcon

                    anchors.centerIn: parent
                    width: root.iconSize
                    height: root.iconSize
                    name: root.idleEnabled ? "eye-off" : "eye"
                    iconColor: root.idleEnabled
                        ? root.textSecondary : root.accent
                }

                HoverHandler {
                    id: idleHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    enabled: !root.idleToggleBusy
                    onTapped: {
                        idleToggleButton.forceActiveFocus()
                        root.idleToggleRequested(!root.idleEnabled)
                    }
                }
            }
        }
    }

    Rectangle {
        id: powerMenu

        anchors.top: topControlRail.bottom
        anchors.topMargin: root.menuGap
        anchors.right: parent.right
        width: Math.max(root.railWidth, contentColumn.implicitWidth + root.unit * 2)
        implicitHeight: contentColumn.height + root.unit * 2
        height: root.powerMenuVisible ? implicitHeight : 0
        radius: Config.Theme.radiusMedium
        clip: true
        color: root.bgGlass
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)
        opacity: root.powerMenuVisible ? 1 : 0
        visible: root.powerMenuVisible || opacity > 0
        enabled: root.powerMenuVisible

        Behavior on opacity {
            enabled: !root.reducedMotion
            NumberAnimation {
                duration: Config.Theme.animNormal
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            enabled: !root.reducedMotion
            NumberAnimation {
                duration: Config.Theme.animNormal
                easing.type: Easing.OutCubic
            }
        }

        Column {
            id: contentColumn

            anchors.top: parent.top
            anchors.topMargin: root.unit
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.unit * 0.5

            Repeater {
                model: [
                    { text: "关机", action: "poweroff" },
                    { text: "休眠", action: "suspend" },
                    { text: "重启", action: "reboot" }
                ]

                delegate: Rectangle {
                    id: menuAction

                    required property var modelData

                    implicitWidth: actionLabel.implicitWidth + root.unit * 1.6
                    width: implicitWidth
                    height: root.unit * 1.8
                    radius: Config.Theme.radiusSmall
                    color: actionHover.hovered
                        ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.text

                    Behavior on color {
                        enabled: !root.reducedMotion
                        ColorAnimation { duration: Config.Theme.animFast }
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return
                                || event.key === Qt.Key_Enter
                                || event.key === Qt.Key_Space) {
                            root.powerActionRequested(modelData.action)
                            event.accepted = true
                        }
                    }

                    Text {
                        id: actionLabel

                        anchors.centerIn: parent
                        text: modelData.text
                        color: root.textPrimary
                        font.family: "Source Han Sans CN"
                        font.pixelSize: root.unit * 0.9
                    }

                    HoverHandler {
                        id: actionHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            menuAction.forceActiveFocus()
                            root.powerActionRequested(modelData.action)
                        }
                    }
                }
            }
        }
    }
}
