import QtQuick
import "config" as Config

// 锁屏认证的无副作用表现层；PAM 生命周期与系统动作由 shell.qml 管理。
Item {
    id: root

    property string username: ""
    property alias passwordText: passwordInput.text
    property bool pamActive: false
    property bool responseVisible: false
    property bool authFailed: false
    property string authStatusText: ""
    property bool reducedMotion: false
    property color bgGlass: Qt.rgba(0.078, 0.078, 0.098, 0.72)
    property color accent: Config.Theme.accent
    property color textPrimary: Config.Theme.textPrimary
    property color textSecondary: Config.Theme.textSecondary
    property color buttonText: "#141414"
    property color errorColor: Config.Theme.danger

    readonly property real credentialWidth: 360
    readonly property real credentialHeight: 54
    readonly property real credentialRadius: 16
    readonly property real submitButtonWidth: 92
    readonly property real submitButtonHeight: 40
    readonly property real submitButtonRadius: 12
    readonly property real statusSlotHeight: 22
    readonly property Item identityRowItem: identityRow
    readonly property Rectangle credentialFieldItem: credentialField
    readonly property TextInput passwordInputItem: passwordInput
    readonly property Text placeholderItem: passwordPlaceholder
    readonly property Rectangle submitButtonItem: submitButton
    readonly property Item statusSlotItem: statusSlot

    signal submitRequested()
    signal passwordEdited()
    signal escapeRequested()

    function focusPasswordField() {
        passwordInput.forceActiveFocus()
    }

    function selectPasswordField() {
        passwordInput.selectAll()
    }

    function clearPassword() {
        passwordInput.clear()
    }

    function triggerErrorWobble() {
        unlockErrorWobble.stop()
        errorShift.x = 0
        if (!root.reducedMotion)
            unlockErrorWobble.start()
    }

    width: credentialWidth
    height: contentColumn.implicitHeight

    Column {
        id: contentColumn

        width: parent.width
        spacing: 16

        Row {
            id: identityRow

            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Rectangle {
                width: 48
                height: 48
                radius: 14
                color: Qt.rgba(root.accent.r, root.accent.g,
                               root.accent.b, 0.18)
                border.width: 1
                border.color: Qt.rgba(root.accent.r, root.accent.g,
                                      root.accent.b, 0.46)

                Text {
                    anchors.centerIn: parent
                    text: root.username.length > 0
                        ? root.username.slice(0, 2).toUpperCase()
                        : "?"
                    color: root.textPrimary
                    font.family: "JetBrains Mono"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    text: root.username || "User"
                    color: root.textPrimary
                    font.family: "JetBrains Mono"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "输入密码以解锁"
                    color: root.textSecondary
                    font.family: "Source Han Sans CN"
                    font.pixelSize: 11
                }
            }
        }

        Column {
            width: parent.width
            spacing: 8

            Rectangle {
                id: credentialField

                width: root.credentialWidth
                height: root.credentialHeight
                radius: root.credentialRadius
                color: passwordInput.activeFocus
                    ? Qt.rgba(root.bgGlass.r, root.bgGlass.g,
                              root.bgGlass.b, 0.78)
                    : Qt.rgba(root.bgGlass.r, root.bgGlass.g,
                              root.bgGlass.b, 0.58)
                border.width: root.authFailed || passwordInput.activeFocus
                    ? 1.5 : 1
                border.color: root.authFailed
                    ? root.errorColor
                    : passwordInput.activeFocus
                        ? root.accent
                        : Qt.rgba(1, 1, 1, 0.12)

                transform: Translate {
                    id: errorShift
                }

                Behavior on color {
                    ColorAnimation {
                        duration: root.reducedMotion
                            ? 0 : Config.Theme.animFast
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: root.reducedMotion
                            ? 0 : Config.Theme.animFast
                    }
                }

                TextInput {
                    id: passwordInput

                    anchors.left: parent.left
                    anchors.right: submitButton.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 18
                    anchors.rightMargin: 12
                    focus: true
                    activeFocusOnTab: true
                    enabled: !root.pamActive
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    color: root.textPrimary
                    selectionColor: root.accent
                    selectedTextColor: root.buttonText
                    font.family: "JetBrains Mono"
                    font.pixelSize: 14
                    echoMode: root.responseVisible
                        ? TextInput.Normal : TextInput.Password
                    inputMethodHints: Qt.ImhHiddenText
                        | Qt.ImhNoPredictiveText
                        | Qt.ImhSensitiveData
                    Accessible.role: Accessible.EditableText
                    Accessible.name: "密码"

                    onAccepted: root.submitRequested()
                    onTextEdited: root.passwordEdited()
                    Keys.onEscapePressed: root.escapeRequested()
                }

                Text {
                    id: passwordPlaceholder

                    anchors.left: passwordInput.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: passwordInput.text.length === 0
                        && !root.pamActive
                    text: "输入密码"
                    color: root.textSecondary
                    opacity: passwordInput.activeFocus ? 0.58 : 0.38
                    font.family: "Source Han Sans CN"
                    font.pixelSize: 13

                    Behavior on opacity {
                        NumberAnimation {
                            duration: root.reducedMotion
                                ? 0 : Config.Theme.animFast
                        }
                    }
                }

                Rectangle {
                    id: submitButton

                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.submitButtonWidth
                    height: root.submitButtonHeight
                    radius: root.submitButtonRadius
                    enabled: !root.pamActive
                    activeFocusOnTab: true
                    color: submitMouse.pressed
                        ? Qt.darker(root.accent, 1.16)
                        : submitMouse.containsMouse
                            ? Qt.lighter(root.accent, 1.05)
                            : root.accent
                    opacity: root.pamActive ? 0.78 : 1
                    Accessible.role: Accessible.Button
                    Accessible.name: root.pamActive ? "正在验证" : "解锁"

                    Behavior on color {
                        ColorAnimation {
                            duration: root.reducedMotion
                                ? 0 : Config.Theme.animFast
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: root.reducedMotion
                                ? 0 : Config.Theme.animFast
                        }
                    }

                    Keys.onPressed: event => {
                        if (!root.pamActive
                                && (event.key === Qt.Key_Return
                                    || event.key === Qt.Key_Enter
                                    || event.key === Qt.Key_Space)) {
                            root.submitRequested()
                            event.accepted = true
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !root.pamActive
                        text: "解锁"
                        color: root.buttonText
                        font.family: "Source Han Sans CN"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.8
                    }

                    Item {
                        id: loadingSpinner

                        anchors.centerIn: parent
                        visible: root.pamActive
                        width: 18
                        height: 18
                        transformOrigin: Item.Center

                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 850
                            loops: Animation.Infinite
                            running: root.pamActive && !root.reducedMotion
                        }

                        Repeater {
                            model: 8

                            delegate: Item {
                                required property int index

                                width: loadingSpinner.width
                                height: loadingSpinner.height
                                anchors.centerIn: parent
                                rotation: index * 45

                                Rectangle {
                                    width: 2
                                    height: 5
                                    radius: width / 2
                                    color: root.buttonText
                                    opacity: 0.22 + index * 0.09
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: submitMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !root.pamActive
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            submitButton.forceActiveFocus()
                            root.submitRequested()
                        }
                    }
                }
            }

            Item {
                id: statusSlot

                width: parent.width
                height: root.statusSlotHeight

                Text {
                    anchors.centerIn: parent
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.authStatusText
                    visible: text.length > 0
                    color: root.authFailed
                        ? root.errorColor : root.textSecondary
                    font.family: "Source Han Sans CN"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }
    }

    SequentialAnimation {
        id: unlockErrorWobble

        NumberAnimation {
            target: errorShift
            property: "x"
            to: -6
            duration: 42
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: errorShift
            property: "x"
            to: 5
            duration: 54
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: errorShift
            property: "x"
            to: -3
            duration: 48
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: errorShift
            property: "x"
            to: 0
            duration: 56
            easing.type: Easing.OutCubic
        }
    }
}
