import ".." as Core
import "../config" as Config
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Rectangle {
    id: root

    required property var shellRoot
    property bool open: false
    property bool closing: false
    property real panelOffsetY: 56
    property real rightMargin: 12
    property real preferredWidth: 440
    property color backgroundColor: "#101010"
    property color surfaceColor: "#1c1c1c"
    property color elevatedColor: "#252525"
    property color borderColor: "#303030"
    property color textColor: "#d0d0d0"
    property color mutedColor: "#707070"
    property color accentColor: "#8fb3c5"
    property color dangerColor: "#9a5555"
    property bool reducedMotion: Core.TopBarState.reducedMotion

    readonly property int diskPercent: {
        const value = parseInt(shellRoot.nvmeUsage)
        return isNaN(value) ? 0 : Math.max(0, Math.min(100, value))
    }
    readonly property bool networkConnected: shellRoot.networkType !== "disconnected"
    readonly property bool wiredConnection: shellRoot.networkType === "ethernet"
    readonly property string networkTitle: wiredConnection
        ? "Ethernet" : shellRoot.wifiAvailable ? "Wi-Fi" : "Network"
    readonly property string networkLabel: wiredConnection
        ? (shellRoot.netSSID + (shellRoot.networkDevice ? " · " + shellRoot.networkDevice : ""))
        : shellRoot.wifiAvailable
            ? (shellRoot.wifiEnabled ? shellRoot.netSSID : "Off")
            : "No network device"

    x: parent ? parent.width - width - rightMargin : 0
    y: panelOffsetY + (open ? 0 : -10)
    width: Math.min(preferredWidth, parent ? parent.width - rightMargin * 2 : preferredWidth)
    height: {
        const desired = header.implicitHeight + contentColumn.implicitHeight + 62
        return parent ? Math.max(0, Math.min(desired, parent.height - panelOffsetY - 12)) : desired
    }
    z: 2
    radius: 28
    color: backgroundColor
    border.color: borderColor
    border.width: 1
    clip: true
    enabled: open
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.94
    transformOrigin: Item.TopRight

    Behavior on y {
        enabled: !root.reducedMotion
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        enabled: !root.reducedMotion
        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
    }
    Behavior on scale {
        enabled: !root.reducedMotion
        NumberAnimation { duration: 240; easing.type: Easing.OutBack }
    }

    Process {
        id: settingsProcess
        command: ["kitty", "--class", "quickshell-network-settings", "nmtui"]
    }
    Process { id: lockProcess; command: ["loginctl", "lock-session"] }
    Process { id: powerProcess; command: ["wlogout"] }

    MouseArea {
        anchors.fill: parent
        onPressed: mouse => mouse.accepted = true
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 22
        spacing: 18

        RowLayout {
            id: header
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                spacing: 0

                Text {
                    id: timeText
                    text: Qt.formatTime(new Date(), "HH:mm")
                    font.family: "JetBrains Mono"
                    font.pixelSize: 38
                    font.weight: Font.Black
                    color: root.textColor
                }

                Text {
                    text: Qt.formatDate(new Date(), "dddd, MMMM d").toUpperCase()
                    font.family: "JetBrains Mono"
                    font.pixelSize: 10
                    font.letterSpacing: 1.2
                    color: root.mutedColor
                }

                Timer {
                    interval: 1000
                    running: root.open
                    repeat: true
                    onTriggered: timeText.text = Qt.formatTime(new Date(), "HH:mm")
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: Config.BarTuning.controlCenterWeatherDividerHeight
                Layout.alignment: Qt.AlignVCenter
                color: root.borderColor
            }

            Text {
                Layout.preferredWidth: Config.BarTuning.controlCenterWeatherWidth
                Layout.alignment: Qt.AlignVCenter
                text: Core.TopBarState.weatherText
                color: root.mutedColor
                font.family: "JetBrains Mono"
                font.pixelSize: Config.BarTuning.clockWeatherFontSize
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            Item { Layout.fillWidth: true }

            HeaderButton {
                icon: "󰒓"
                onClicked: settingsProcess.running = true
            }
            HeaderButton {
                icon: "󰌾"
                onClicked: lockProcess.running = true
            }
            HeaderButton {
                icon: "󰐥"
                danger: true
                onClicked: powerProcess.running = true
            }
        }

        Flickable {
            id: contentFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: contentColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: contentColumn
                width: contentFlick.width
                spacing: 14

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 10

                    ControlCenterQuickToggle {
                        icon: root.wiredConnection ? "󰈀" : root.networkConnected ? "󰖩" : "󰖪"
                        label: root.networkTitle
                        subLabel: root.networkLabel
                        active: root.networkConnected || (!root.wiredConnection && root.shellRoot.wifiEnabled)
                        interactive: !root.wiredConnection && root.shellRoot.wifiAvailable
                        activeColor: root.accentColor
                        surfaceColor: root.surfaceColor
                        textColor: root.textColor
                        mutedColor: root.mutedColor
                        reducedMotion: root.reducedMotion
                        onClicked: root.shellRoot.toggleWifi()
                    }

                    ControlCenterQuickToggle {
                        icon: root.shellRoot.btStatus === "ON" ? "󰂯" : "󰂲"
                        label: "Bluetooth"
                        subLabel: !root.shellRoot.bluetoothAvailable
                            ? "Unavailable" : root.shellRoot.btStatus === "ON" ? "On" : "Off"
                        active: root.shellRoot.btStatus === "ON"
                        interactive: root.shellRoot.bluetoothAvailable
                        activeColor: root.accentColor
                        surfaceColor: root.surfaceColor
                        textColor: root.textColor
                        mutedColor: root.mutedColor
                        reducedMotion: root.reducedMotion
                        onClicked: root.shellRoot.toggleBluetooth()
                    }
                }

                ControlCenterSlider {
                    icon: root.shellRoot.volumeMuted
                        ? "󰝟"
                        : root.shellRoot.volumePercent > 66 ? "󰕾"
                        : root.shellRoot.volumePercent > 33 ? "󰖀" : "󰕿"
                    value: root.shellRoot.volumePercent
                    inactive: root.shellRoot.volumeMuted
                    accentColor: root.accentColor
                    surfaceColor: root.surfaceColor
                    textColor: root.textColor
                    mutedColor: root.mutedColor
                    reducedMotion: root.reducedMotion
                    onValueRequested: value => root.shellRoot.setVolume(value)
                    onIconClicked: root.shellRoot.toggleMute()
                }

                ControlCenterSlider {
                    icon: root.shellRoot.brightnessPercent > 70 ? "󰃠"
                        : root.shellRoot.brightnessPercent > 30 ? "󰃟" : "󰃞"
                    value: root.shellRoot.brightnessPercent
                    accentColor: root.accentColor
                    surfaceColor: root.surfaceColor
                    textColor: root.textColor
                    mutedColor: root.mutedColor
                    reducedMotion: root.reducedMotion
                    onValueRequested: value => root.shellRoot.setBrightness(Math.round(value))
                }

                ControlCenterStats {
                    cpuPercent: Core.TopBarState.cpuPercent
                    memoryPercent: Core.TopBarState.memPercent
                    diskPercent: root.diskPercent
                    surfaceColor: root.surfaceColor
                    textColor: root.textColor
                    mutedColor: root.mutedColor
                    accentColor: root.accentColor
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: mediaContent.visible ? 96 : 62
                    radius: 22
                    color: root.surfaceColor
                    border.color: Qt.rgba(1, 1, 1, 0.05)

                    RowLayout {
                        id: mediaContent
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12
                        visible: root.shellRoot.mprisPlayer !== null

                        Rectangle {
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 64
                            radius: 14
                            clip: true
                            color: root.elevatedColor

                            Image {
                                id: albumArt
                                anchors.fill: parent
                                source: root.shellRoot.mediaArtUrl
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: albumArt.status !== Image.Ready
                                text: "󰝚"
                                font.family: "Material Design Icons"
                                font.pixelSize: 28
                                color: root.mutedColor
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                Layout.fillWidth: true
                                text: root.shellRoot.mediaTitle
                                elide: Text.ElideRight
                                font.family: "JetBrains Mono"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: root.textColor
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.shellRoot.mediaArtist
                                elide: Text.ElideRight
                                font.family: "JetBrains Mono"
                                font.pixelSize: 10
                                color: root.mutedColor
                            }
                        }

                        HeaderButton {
                            icon: root.shellRoot.mediaPlaying ? "󰏤" : "󰐊"
                            emphasized: true
                            onClicked: {
                                if (root.shellRoot.mprisPlayer)
                                    root.shellRoot.mprisPlayer.togglePlaying()
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !mediaContent.visible
                        text: "NO ACTIVE MEDIA"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 11
                        font.letterSpacing: 1
                        color: root.mutedColor
                    }
                }

                Item { Layout.preferredHeight: 1 }
            }
        }
    }

    component HeaderButton: Rectangle {
        id: button
        property string icon: ""
        property bool danger: false
        property bool emphasized: false
        signal clicked()

        Layout.preferredWidth: emphasized ? 48 : 40
        Layout.preferredHeight: width
        radius: width / 2
        color: emphasized ? root.accentColor
            : buttonMouse.pressed ? root.elevatedColor
            : buttonMouse.containsMouse ? root.surfaceColor : "transparent"

        Text {
            anchors.centerIn: parent
            text: button.icon
            font.family: "Material Design Icons"
            font.pixelSize: button.emphasized ? 24 : 20
            color: button.emphasized ? root.backgroundColor
                : button.danger ? root.dangerColor : root.textColor
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
