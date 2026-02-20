import QtQuick

// SystemPanel（系统面板内容组件）
// - 从 shell.qml 抽离并组件化
// - 动画复刻 CenterPanel.qml 的"卷轴展开"逻辑：height 展开 + y 微调 + opacity
Rectangle {
    id: systemPanel

    required property var root
    required property var systemPanelCloseTimer

    property bool systemPanelVisible: false
    property bool systemPanelClosing: false

    property real panelGap: 0
    property real panelLabelWidth: 0
    property real panelOffsetY: 0
    property real panelPadding: 0
    property real panelRadius: 0
    property real panelWidth: 0
    property real barMarginSide: 0
    property real panelSectionGap: 0
    property real panelRowGap: 0
    property real panelRowHeight: 0

    property real fontSecondary: 12
    property real fontSection: 11
    property real fontTiny: 10

    property string gpuInfo: ""
    property string nvmeUsage: "0%"
    property string loadAvg: ""
    property int processCount: 0
    property real memTotal: 0
    property real memUsed: 0
    property string kernelVer: ""
    property string cpuModel: ""
    property string uptime: ""

    property color zenVoid: "transparent"
    property color zenInk: "transparent"
    property color zenStone: "transparent"
    property color zenMist: "transparent"
    property color zenAsh: "transparent"
    property color zenSmoke: "transparent"
    property color zenCloud: "transparent"
    property color zenSnow: "transparent"
    property color zenPure: "transparent"
    property color zenAccent: "transparent"

    // 全局字体常量
    readonly property string monoFont: "JetBrainsMono Nerd Font"

    z: 1
    x: parent ? (parent.width - panelWidth - barMarginSide) : 0
    y: panelOffsetY + (systemPanelVisible ? 0 : -8)
    width: panelWidth
    height: systemPanelVisible ? (panelContent.height + panelPadding * 2) : 0

    color: zenInk
    border.color: zenMist
    border.width: 1
    radius: panelRadius
    clip: true
    opacity: systemPanelVisible ? 1 : 0

    Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

    MouseArea {
        anchors.fill: parent
        propagateComposedEvents: false
        onPressed: function(mouse) { mouse.accepted = false }
    }

    // 点线填充辅助函数
    function dotFill(label, value, totalWidth) {
        var fm = Qt.fontMetrics
        // 粗略估算：用固定字符宽度近似
        var charWidth = fontSecondary * 0.6
        var labelChars = label.length
        var valueChars = value.length
        var availChars = Math.floor(totalWidth / charWidth) - labelChars - valueChars - 2
        var dots = ""
        for (var i = 0; i < availChars; i++) dots += "·"
        return dots
    }

    Column {
        id: panelContent
        anchors.top: parent.top
        anchors.topMargin: panelPadding
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: panelSectionGap

        // ===== 盒子1: GRAPHICS =====
        Column {
            x: panelPadding
            width: parent.width - panelPadding * 2
            spacing: panelRowGap

            Item {
                width: parent.width; height: fontSection
                Text { text: "[ GPU_CORE ]"; font.pixelSize: fontSection; font.letterSpacing: 3; font.family: monoFont; color: zenAsh; anchors.left: parent.left }
                Text { text: "⌜"; font.pixelSize: fontSection; font.family: monoFont; color: zenMist; anchors.right: parent.right }
            }

            Item {
                width: parent.width; height: panelRowHeight
                Text {
                    id: gpuLabel
                    anchors.left: parent.left; text: "GPU"; font.pixelSize: fontSecondary; font.family: monoFont; color: zenSmoke
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.left: gpuLabel.right; anchors.right: parent.right
                    anchors.leftMargin: panelGap
                    text: gpuInfo; font.pixelSize: fontSecondary; font.family: monoFont; color: zenCloud
                    horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Text { x: panelPadding; width: parent.width - panelPadding * 2; text: "─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─"; font.pixelSize: fontTiny; font.family: monoFont; color: zenMist; horizontalAlignment: Text.AlignHCenter; clip: true }

        // ===== 盒子2: STORAGE =====
        Column {
            x: panelPadding
            width: parent.width - panelPadding * 2
            spacing: panelRowGap

            Item {
                width: parent.width; height: fontSection
                Text { text: "[ DISK_IO ]"; font.pixelSize: fontSection; font.letterSpacing: 3; font.family: monoFont; color: zenAsh; anchors.left: parent.left }
                Text { text: "⌜"; font.pixelSize: fontSection; font.family: monoFont; color: zenMist; anchors.right: parent.right }
            }

            Item {
                width: parent.width; height: panelRowHeight
                Text {
                    id: nvmeLabel
                    text: "NVME"; font.pixelSize: fontSecondary; font.family: monoFont; color: zenSmoke
                    width: panelLabelWidth * 0.5; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: nvmeValue
                    text: nvmeUsage; font.pixelSize: fontSecondary; font.family: monoFont; color: zenCloud
                    width: panelLabelWidth * 0.8; anchors.right: parent.right; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.left: nvmeLabel.right; anchors.right: nvmeValue.left
                    anchors.leftMargin: panelGap * 2; anchors.rightMargin: panelGap * 2
                    text: {
                        var p = parseInt(nvmeUsage)
                        var pct = isNaN(p) ? 0 : Math.max(0, Math.min(100, p))
                        return root.getAsciiBar(pct, 18)
                    }
                    font.pixelSize: fontSecondary; font.family: monoFont; color: zenCloud
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Text { x: panelPadding; width: parent.width - panelPadding * 2; text: "─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─"; font.pixelSize: fontTiny; font.family: monoFont; color: zenMist; horizontalAlignment: Text.AlignHCenter; clip: true }

        // ===== 盒子3: PERFORMANCE =====
        Column {
            x: panelPadding
            width: parent.width - panelPadding * 2
            spacing: panelRowGap

            Item {
                width: parent.width; height: fontSection
                Text { text: "[ PROC_MON ]"; font.pixelSize: fontSection; font.letterSpacing: 3; font.family: monoFont; color: zenAsh; anchors.left: parent.left }
                Text { text: "⌜"; font.pixelSize: fontSection; font.family: monoFont; color: zenMist; anchors.right: parent.right }
            }

            Item {
                width: parent.width; height: panelRowHeight
                Text {
                    id: loadLabel; anchors.left: parent.left; text: "LOAD"; font.pixelSize: fontSecondary; font.family: monoFont; color: zenSmoke
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: loadDots; anchors.left: loadLabel.right; anchors.right: loadValue.left
                    anchors.leftMargin: panelGap; anchors.rightMargin: panelGap
                    text: "····················"; font.pixelSize: fontTiny; font.family: monoFont; color: zenMist
                    anchors.verticalCenter: parent.verticalCenter; clip: true
                }
                Text {
                    id: loadValue; anchors.right: parent.right; text: loadAvg; font.pixelSize: fontSecondary; font.family: monoFont; color: zenCloud
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item {
                width: parent.width; height: panelRowHeight
                Text {
                    id: procsLabel; anchors.left: parent.left; text: "PROCS"; font.pixelSize: fontSecondary; font.family: monoFont; color: zenSmoke
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.left: procsLabel.right; anchors.right: procsValue.left
                    anchors.leftMargin: panelGap; anchors.rightMargin: panelGap
                    text: "····················"; font.pixelSize: fontTiny; font.family: monoFont; color: zenMist
                    anchors.verticalCenter: parent.verticalCenter; clip: true
                }
                Text {
                    id: procsValue; anchors.right: parent.right; text: processCount.toString(); font.pixelSize: fontSecondary; font.family: monoFont; color: zenCloud
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item {
                width: parent.width; height: panelRowHeight
                Text {
                    id: memLabel; anchors.left: parent.left; text: "MEM"; font.pixelSize: fontSecondary; font.family: monoFont; color: zenSmoke
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.left: memLabel.right; anchors.right: memValue.left
                    anchors.leftMargin: panelGap; anchors.rightMargin: panelGap
                    text: "····················"; font.pixelSize: fontTiny; font.family: monoFont; color: zenMist
                    anchors.verticalCenter: parent.verticalCenter; clip: true
                }
                Text {
                    id: memValue; anchors.right: parent.right; text: memUsed.toFixed(1) + "G / " + memTotal.toFixed(0) + "G"; font.pixelSize: fontSecondary; font.family: monoFont; color: zenCloud
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Text { x: panelPadding; width: parent.width - panelPadding * 2; text: "─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─"; font.pixelSize: fontTiny; font.family: monoFont; color: zenMist; horizontalAlignment: Text.AlignHCenter; clip: true }

        // ===== 盒子4: SYSTEM =====
        Column {
            x: panelPadding
            width: parent.width - panelPadding * 2
            spacing: panelRowGap

            Item {
                width: parent.width; height: fontSection
                Text { text: "[ SYS_INFO ]"; font.pixelSize: fontSection; font.letterSpacing: 3; font.family: monoFont; color: zenAsh; anchors.left: parent.left }
                Text { text: "⌜"; font.pixelSize: fontSection; font.family: monoFont; color: zenMist; anchors.right: parent.right }
            }

            Item {
                width: parent.width; height: panelRowHeight
                Text {
                    id: kernelLabel; anchors.left: parent.left; text: "KERNEL"; font.pixelSize: fontSecondary; font.family: monoFont; color: zenSmoke
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.left: kernelLabel.right; anchors.right: kernelValue.left
                    anchors.leftMargin: panelGap; anchors.rightMargin: panelGap
                    text: "····················"; font.pixelSize: fontTiny; font.family: monoFont; color: zenMist
                    anchors.verticalCenter: parent.verticalCenter; clip: true
                }
                Text {
                    id: kernelValue; anchors.right: parent.right; text: kernelVer; font.pixelSize: fontSecondary; font.family: monoFont; color: zenCloud
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item {
                width: parent.width; height: panelRowHeight
                Text {
                    id: cpuLabel; anchors.left: parent.left; text: "CPU"; font.pixelSize: fontSecondary; font.family: monoFont; color: zenSmoke
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.left: cpuLabel.right; anchors.right: parent.right
                    anchors.leftMargin: panelGap
                    text: cpuModel; font.pixelSize: fontSecondary; font.family: monoFont; color: zenCloud
                    horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item {
                width: parent.width; height: panelRowHeight
                Text {
                    id: uptimeLabel; anchors.left: parent.left; text: "UPTIME"; font.pixelSize: fontSecondary; font.family: monoFont; color: zenSmoke
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.left: uptimeLabel.right; anchors.right: uptimeValue.left
                    anchors.leftMargin: panelGap; anchors.rightMargin: panelGap
                    text: "····················"; font.pixelSize: fontTiny; font.family: monoFont; color: zenMist
                    anchors.verticalCenter: parent.verticalCenter; clip: true
                }
                Text {
                    id: uptimeValue; anchors.right: parent.right; text: uptime; font.pixelSize: fontSecondary; font.family: monoFont; color: zenCloud
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Item { width: 1; height: panelGap * 2 }
    }
}