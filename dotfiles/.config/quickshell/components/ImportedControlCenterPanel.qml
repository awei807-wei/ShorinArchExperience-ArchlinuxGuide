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
    property bool embedded: false
    property real panelOffsetY: 56
    property real rightMargin: 12
    property real preferredWidth: 440
    property color backgroundColor: "#101010"
    property color surfaceColor: "#1c1c1c"
    property color elevatedColor: "#252525"
    property color borderColor: Config.Theme.outline
    property color textColor: "#d0d0d0"
    property color mutedColor: "#707070"
    property color accentColor: "#8fb3c5"
    property color dangerColor: Config.Theme.danger
    property bool reducedMotion: Core.TopBarState.reducedMotion

    readonly property int diskPercent: {
        const value = parseInt(shellRoot.nvmeUsage)
        return isNaN(value) ? 0 : Math.max(0, Math.min(100, value))
    }
    readonly property bool networkConnected: shellRoot.networkType !== "disconnected"
    readonly property real contentRequiredHeight: contentColumn.implicitHeight
    readonly property real contentViewportHeight: contentFlick.height
    readonly property bool baseContentFits: contentRequiredHeight
        <= contentViewportHeight + 1
    readonly property bool wiredConnection: shellRoot.networkType === "ethernet"
    readonly property string networkTitle: wiredConnection
        ? "Ethernet" : shellRoot.wifiAvailable ? "Wi-Fi" : "Network"
    readonly property string networkLabel: wiredConnection
        ? (shellRoot.netSSID + (shellRoot.networkDevice ? " · " + shellRoot.networkDevice : ""))
        : shellRoot.wifiAvailable
            ? (shellRoot.wifiEnabled ? shellRoot.netSSID : "Off")
            : "No network device"

    x: embedded ? 0 : (parent ? parent.width - width - rightMargin : 0)
    y: embedded ? 0 : panelOffsetY + (open ? 0 : -10)
    width: embedded
        ? (parent ? parent.width : preferredWidth)
        : Math.min(preferredWidth, parent ? parent.width - rightMargin * 2 : preferredWidth)
    height: {
        if (embedded)
            return parent ? parent.height : preferredWidth
        const desired = header.implicitHeight + contentColumn.implicitHeight + 62
        return parent ? Math.max(0, Math.min(desired, parent.height - panelOffsetY - 12)) : desired
    }
    z: 2
    radius: embedded ? 0 : Config.Theme.radiusLarge
    color: embedded ? "transparent" : backgroundColor
    border.color: borderColor
    border.width: embedded ? 0 : 1
    clip: true
    enabled: open
    opacity: embedded ? 1 : (open ? 1 : 0)
    scale: embedded ? 1 : (open ? 1 : 0.94)
    transformOrigin: Item.TopRight

    onOpenChanged: {
        if (!open)
            volumeSlider.collapseSelector()
    }

    Behavior on y {
        enabled: !root.embedded && !root.reducedMotion
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        enabled: !root.embedded && !root.reducedMotion
        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
    }
    Behavior on scale {
        enabled: !root.embedded && !root.reducedMotion
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    // 打开时的全屏背景遮罩（点击外部关闭由 shell.qml 的全屏 MouseArea 处理，这里只负责视觉）
    Rectangle {
        z: -1
        visible: !root.embedded
        x: -root.x
        y: -root.y
        width: root.parent ? root.parent.width : 0
        height: root.parent ? root.parent.height : 0
        color: Config.Theme.shadowColor
        opacity: root.open ? 0.4 : 0

        Behavior on opacity {
            enabled: !root.reducedMotion
            NumberAnimation { duration: Config.Theme.animNormal; easing.type: Easing.OutQuad }
        }
    }

    // 柔和投影（轻量实现：底下垫两层半透明黑矩形，避免 GraphicalEffects 的 DropShadow 开销）
    Rectangle {
        z: -1
        visible: !root.embedded
        anchors.fill: parent
        anchors.margins: -1
        radius: root.radius + 1
        color: "#000000"
        opacity: 0.18
    }

    Rectangle {
        z: -1
        visible: !root.embedded
        anchors.fill: parent
        anchors.topMargin: 2
        radius: root.radius
        color: "#000000"
        opacity: 0.35
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
        anchors.margins: root.embedded ? 0 : 22
        spacing: root.embedded ? Config.BarTuning.rightPanelControlGap : 18

        RowLayout {
            id: header
            Layout.fillWidth: true
            Layout.preferredHeight: root.embedded
                ? Config.BarTuning.rightPanelControlHeaderHeight
                : -1
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

            ControlCenterHeaderButton {
                icon: "󰒓"
                toolTip: "Network Settings"
                accentColor: root.accentColor
                elevatedColor: root.elevatedColor
                surfaceColor: root.surfaceColor
                textColor: root.textColor
                dangerColor: root.dangerColor
                reducedMotion: root.reducedMotion
                onClicked: settingsProcess.running = true
            }
            ControlCenterHeaderButton {
                icon: "󰌾"
                toolTip: "Lock"
                accentColor: root.accentColor
                elevatedColor: root.elevatedColor
                surfaceColor: root.surfaceColor
                textColor: root.textColor
                dangerColor: root.dangerColor
                reducedMotion: root.reducedMotion
                onClicked: lockProcess.running = true
            }
            ControlCenterHeaderButton {
                icon: "󰐥"
                toolTip: "Power"
                danger: true
                accentColor: root.accentColor
                elevatedColor: root.elevatedColor
                surfaceColor: root.surfaceColor
                textColor: root.textColor
                dangerColor: root.dangerColor
                reducedMotion: root.reducedMotion
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
                spacing: root.embedded
                    ? Config.BarTuning.rightPanelControlGap : 14

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
                    id: volumeSlider

                    icon: root.shellRoot.volumeMuted
                        ? "󰝟"
                        : root.shellRoot.volumePercent > 66 ? "󰕾"
                        : root.shellRoot.volumePercent > 33 ? "󰖀" : "󰕿"
                    toolTip: "音量"
                    value: root.shellRoot.volumePercent
                    inactive: root.shellRoot.volumeMuted
                    accentColor: root.accentColor
                    surfaceColor: root.surfaceColor
                    textColor: root.textColor
                    mutedColor: root.mutedColor
                    reducedMotion: root.reducedMotion
                    selectorVisible: true
                    selectorModel: root.shellRoot.audioOutputOptions
                    selectorCurrentIndex: root.shellRoot.audioOutputCurrentIndex
                    selectorPlaceholder: root.shellRoot.audioOutputPlaceholder
                    selectorEnabled: root.shellRoot.audioOutputsReady
                    onValueRequested: value => root.shellRoot.setVolume(value)
                    onIconClicked: root.shellRoot.toggleMute()
                    onSelectorRequested: index => root.shellRoot.selectAudioOutput(index)
                }

                ControlCenterSlider {
                    icon: root.shellRoot.brightnessPercent > 70 ? "󰃠"
                        : root.shellRoot.brightnessPercent > 30 ? "󰃟" : "󰃞"
                    toolTip: "亮度"
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

                ControlCenterMediaCard {
                    shellRoot: root.shellRoot
                    surfaceColor: root.surfaceColor
                    elevatedColor: root.elevatedColor
                    textColor: root.textColor
                    mutedColor: root.mutedColor
                    accentColor: root.accentColor
                    dangerColor: root.dangerColor
                    reducedMotion: root.reducedMotion
                }

                Item { Layout.preferredHeight: 1 }
            }
        }
    }

}
