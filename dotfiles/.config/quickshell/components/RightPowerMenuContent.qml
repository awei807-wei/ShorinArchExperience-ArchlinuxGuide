import "../config" as Config
import QtQuick
import Quickshell
import Quickshell.Io

// 右侧电源菜单内容：
// 完全复刻 Brain_Shell 的电源动作列表、键盘上下键导航、悬停动效与二次确认逻辑。
Item {
    id: root

    signal closeRequested()

    property int selectedIndex: 0
    property string confirmingAction: "" // "" 为常规列表，否则展示确认卡片
    property string confirmingTitle: ""
    property string confirmingMessage: ""

    readonly property var actions: [
        {
            label: "Shut Down",
            icon: "⏻",
            danger: true,
            confirm: true,
            title: "Shut Down?",
            message: "Your computer will power off.",
            action: "shutdown"
        },
        {
            label: "Reboot",
            icon: "↺",
            danger: true,
            confirm: true,
            title: "Reboot?",
            message: "Your computer will restart.",
            action: "reboot"
        },
        {
            label: "Log Out",
            icon: "󰍃",
            danger: true,
            confirm: true,
            title: "Log Out?",
            message: "You will be logged out of your session.",
            action: "logout"
        },
        {
            label: "Lock",
            icon: "󰌾",
            danger: false,
            confirm: false,
            action: "lock"
        },
        {
            label: "Suspend",
            icon: "⏾",
            danger: false,
            confirm: false,
            action: "suspend"
        }
    ]

    Process {
        id: proc
        property var pendingCmd: []
        command: pendingCmd
    }

    function executeAction(act) {
        switch (act) {
            case "lock":
                proc.pendingCmd = ["bash", "-c", "if [ -x ~/.config/quickshell/scripts/lockscreen.sh ]; then ~/.config/quickshell/scripts/lockscreen.sh; else loginctl lock-session; fi"]
                proc.running = true
                break
            case "suspend":
                proc.pendingCmd = ["systemctl", "suspend"]
                proc.running = true
                break
            case "logout":
                proc.pendingCmd = ["bash", "-c", "niri msg action quit || hyprctl dispatch exit || loginctl terminate-user $USER"]
                proc.running = true
                break
            case "reboot":
                proc.pendingCmd = ["systemctl", "reboot"]
                proc.running = true
                break
            case "shutdown":
                proc.pendingCmd = ["systemctl", "poweroff"]
                proc.running = true
                break
        }
        root.closeRequested()
    }

    function requestAction(item) {
        if (item.confirm) {
            confirmingAction = item.action
            confirmingTitle = item.title
            confirmingMessage = item.message
        } else {
            executeAction(item.action)
        }
    }

    focus: true
    Keys.onEscapePressed: {
        if (confirmingAction !== "") {
            confirmingAction = ""
        } else {
            root.closeRequested()
        }
    }

    Keys.onUpPressed: {
        if (confirmingAction !== "") return
        if (selectedIndex > 0) selectedIndex--
        else selectedIndex = actions.length - 1
    }

    Keys.onDownPressed: {
        if (confirmingAction !== "") return
        if (selectedIndex < actions.length - 1) selectedIndex++
        else selectedIndex = 0
    }

    Keys.onReturnPressed: {
        if (confirmingAction !== "") {
            executeAction(confirmingAction)
            confirmingAction = ""
        } else if (selectedIndex >= 0 && selectedIndex < actions.length) {
            requestAction(actions[selectedIndex])
        }
    }

    // --- 常规动作列表 ---
    Column {
        id: actionCol
        anchors.fill: parent
        spacing: 6
        visible: root.confirmingAction === ""

        Repeater {
            model: root.actions

            delegate: Rectangle {
                id: itemCard
                width: actionCol.width
                height: 42
                radius: Config.Theme.radiusSmall

                readonly property bool isSelected: root.selectedIndex === index
                readonly property bool isHovered: hov.hovered || isSelected

                color: isHovered
                    ? (modelData.danger
                        ? Qt.rgba(0.65, 0.22, 0.22, 0.75)
                        : Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.35))
                    : "transparent"

                border.color: isHovered
                    ? (modelData.danger ? Config.Theme.danger : Config.Theme.accent)
                    : "transparent"
                border.width: isHovered ? 1 : 0

                Behavior on color {
                    ColorAnimation { duration: Config.Theme.animFast }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: modelData.icon
                        font.pixelSize: 15
                        color: itemCard.isHovered
                            ? (modelData.danger ? "#ffffff" : Config.Theme.textPrimary)
                            : Config.Theme.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: modelData.label
                        font.pixelSize: 12
                        font.bold: itemCard.isHovered
                        color: itemCard.isHovered
                            ? (modelData.danger ? "#ffffff" : Config.Theme.textPrimary)
                            : Config.Theme.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler {
                    id: hov
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: if (hovered) root.selectedIndex = index
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.requestAction(modelData)
                }
            }
        }
    }

    // --- 二次确认提示卡片 ---
    Column {
        id: confirmCol
        anchors.centerIn: parent
        width: parent.width - 12
        spacing: 12
        visible: root.confirmingAction !== ""

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "⚠️"
            font.pixelSize: 28
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.confirmingTitle
            font.pixelSize: 14
            font.bold: true
            color: Config.Theme.textPrimary
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            text: root.confirmingMessage
            font.pixelSize: 11
            color: Config.Theme.textMuted
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            // 取消按钮
            Rectangle {
                width: 84
                height: 32
                radius: Config.Theme.radiusSmall
                color: cancelHov.hovered
                    ? Config.Theme.surfaceContainer
                    : Config.Theme.outline

                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    font.pixelSize: 11
                    color: Config.Theme.textSecondary
                }

                HoverHandler { id: cancelHov; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.confirmingAction = ""
                }
            }

            // 确认执行按钮
            Rectangle {
                width: 84
                height: 32
                radius: Config.Theme.radiusSmall
                color: confirmHov.hovered
                    ? Qt.darker(Config.Theme.danger, 1.15)
                    : Config.Theme.danger

                Text {
                    anchors.centerIn: parent
                    text: "Confirm"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#ffffff"
                }

                HoverHandler { id: confirmHov; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.executeAction(root.confirmingAction)
                        root.confirmingAction = ""
                    }
                }
            }
        }
    }
}