// QuickSettings — 真实数据版。
// 亮度走 brightnessctl，Wi-Fi 走 nmcli，蓝牙走 bluetoothctl。
// DND 无系统级后端（shell 自有通知服务器），保留纯状态开关。
import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../../"

Rectangle {
    id: root

    radius: 16
    color: Qt.rgba(1, 1, 1, 0.03)
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1

    // ── 亮度 ─────────────────────────────────────────────────────────
    property real _brightVal: 0.72
    property bool _brightBusy: false

    property Process briGetProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                // brightnessctl -m: device,type,cur,max,pct
                const fields = this.text.trim().split("\n")[0].split(",")
                if (fields.length < 5)
                    return
                const max = Number(fields[3])
                const cur = Number(fields[2])
                if (!(max > 0 && isFinite(cur)))
                    return
                root._brightBusy = true
                root._brightVal = Math.max(0, Math.min(1, cur / max))
                root._brightBusy = false
            }
        }
    }

    property Process briSetProc: Process {
        onExited: {
            briGetProc.command = ["brightnessctl", "-m"]
            briGetProc.running = false
            briGetProc.running = true
        }
    }

    function setBrightness(pct) {
        briSetProc.command = ["brightnessctl", "set", Math.round(pct) + "%"]
        briSetProc.running = false
        briSetProc.running = true
    }

    // ── Wi-Fi ────────────────────────────────────────────────────────
    property bool _wifiOn: true
    property string _ssid: "—"

    property Process wifiProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root._wifiOn = this.text.trim() === "enabled"
            }
        }
    }

    property Process ssidProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of this.text.split("\n")) {
                    if (line.startsWith("yes:")) {
                        root._ssid = line.slice(4).trim() || "—"
                        return
                    }
                }
                root._ssid = root._wifiOn ? "未连接" : "—"
            }
        }
    }

    property Process wifiSetProc: Process {
        onExited: root.startRefresh()
    }
    property bool _btOn: false

    property Process btProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root._btOn = this.text.includes("Powered: yes")
            }
        }
    }

    property Process btSetProc: Process {
        onExited: root.startRefresh()
    }

    // ── 统一状态刷新 ────────────────────────────────────────────────
    function startRefresh() {
        wifiProc.command = ["nmcli", "radio", "wifi"]
        wifiProc.running = false
        wifiProc.running = true
        ssidProc.command = ["sh", "-c",
            "nmcli -t -f IN-USE,SSID dev wifi | grep '^yes:'"]
        ssidProc.running = false
        ssidProc.running = true
        btProc.command = ["bluetoothctl", "show"]
        btProc.running = false
        btProc.running = true
    }

    property Timer refreshTimer: Timer {
        interval: 8000
        repeat: true
        running: true
        onTriggered: root.startRefresh()
    }

    Component.onCompleted: startRefresh()

    // ── UI ───────────────────────────────────────────────────────────
    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Text {
            text: "Quick Settings"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Theme.text
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        Text {
            text: "Brightness"
            font.pixelSize: 10
            color: Qt.rgba(1, 1, 1, 0.45)
        }

        Slider {
            id: brightnessSlider

            width: parent.width
            from: 0.2
            to: 1.0
            value: root._brightVal
            onMoved: {
                if (!root._brightBusy)
                    root.setBrightness(value * 100)
            }

            background: Rectangle {
                x: brightnessSlider.leftPadding
                y: brightnessSlider.topPadding
                    + brightnessSlider.availableHeight / 2 - height / 2
                width: brightnessSlider.availableWidth
                height: 4
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.10)

                Rectangle {
                    width: brightnessSlider.visualPosition * parent.width
                    height: parent.height
                    radius: 2
                    color: Theme.active
                }
            }

            handle: Rectangle {
                x: brightnessSlider.leftPadding
                    + brightnessSlider.visualPosition
                        * (brightnessSlider.availableWidth - width)
                y: brightnessSlider.topPadding
                    + brightnessSlider.availableHeight / 2 - height / 2
                width: 14
                height: 14
                radius: 7
                color: Theme.text
            }
        }

        Repeater {
            model: [
                { "key": "wifi", "icon": "󰖩", "title": "Wi-Fi" },
                { "key": "bt", "icon": "󰂯", "title": "Bluetooth" },
                { "key": "dnd", "icon": "󰂛", "title": "Do Not Disturb" }
            ]

            delegate: Item {
                required property int index
                required property var modelData

                readonly property bool on: modelData.key === "wifi"
                    ? root._wifiOn
                    : modelData.key === "bt" ? root._btOn
                    : ShellState.dnd

                readonly property string subtitle: modelData.key === "wifi"
                    ? root._ssid : ""

                width: parent.width
                height: 34

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.icon
                        font.pixelSize: 13
                        color: parent.parent.on ? Theme.active
                                                : Qt.rgba(1, 1, 1, 0.4)
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: modelData.title
                            font.pixelSize: 11
                            color: Theme.text
                        }
                        Text {
                            visible: subtitle !== ""
                            text: subtitle
                            font.pixelSize: 9
                            color: Qt.rgba(1, 1, 1, 0.35)
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 18
                    radius: 9
                    color: parent.on ? Theme.active : Qt.rgba(1, 1, 1, 0.10)

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    Rectangle {
                        x: parent.on ? parent.width - width - 2 : 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 14
                        radius: 7
                        color: parent.on ? "#101010" : Qt.rgba(1, 1, 1, 0.5)

                        Behavior on x {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.key === "wifi") {
                            const next = !root._wifiOn
                            wifiSetProc.command = ["nmcli", "radio", "wifi",
                                next ? "on" : "off"]
                            wifiSetProc.running = false
                            wifiSetProc.running = true
                            root._wifiOn = next
                        } else if (modelData.key === "bt") {
                            const next = !root._btOn
                            btSetProc.command = ["bluetoothctl", "power",
                                next ? "on" : "off"]
                            btSetProc.running = false
                            btSetProc.running = true
                            root._btOn = next
                        } else {
                            ShellState.dnd = !ShellState.dnd
                        }
                    }
                }
            }
        }

        Item {
            width: 1
            height: 1
        }

        Text {
            text: "DND 为状态开关，暂无系统级后端"
            font.pixelSize: 9
            color: Qt.rgba(1, 1, 1, 0.25)
        }
    }
}
