import QtQuick // Rectangle/Text/MouseArea/Animation 等

// SystemPanel（系统面板内容组件）
// - 从 shell.qml 抽离并组件化
// - 动画复刻 CenterPanel.qml 的“卷轴展开”逻辑：height 展开 + y 微调 + opacity
Rectangle {
    id: systemPanel

    // shell.qml 负责注入（保持与 CenterPanel 一致的绑定风格）
    required property var root
    required property var systemPanelCloseTimer

    // 可见性状态（用于动画驱动；Window 级可见性由 shell.qml 管理）
    property bool systemPanelVisible: false
    property bool systemPanelClosing: false // 保留字段：用于与外层 closing 缓冲对齐

    // 布局参数（与 CenterPanel panel* 系列对齐）
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

    // 字体尺寸（像素）
    property real fontSecondary: 12
    property real fontSection: 11
    property real fontTiny: 10

    // 系统状态变量（由 shell.qml 绑定）
    property string gpuInfo: ""
    property string nvmeUsage: "0%"
    property string loadAvg: ""
    property int processCount: 0
    property real memTotal: 0
    property real memUsed: 0
    property string kernelVer: ""
    property string cpuModel: ""
    property string uptime: ""

    // 主题色（zen* 系列全部注入；未必全部在本组件中直接使用）
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

    // 位置与尺寸（靠右、固定宽度；高度随内容展开）
    z: 1
    x: parent ? (parent.width - panelWidth - barMarginSide) : 0
    y: panelOffsetY + (systemPanelVisible ? 0 : -8)
    width: panelWidth
    height: systemPanelVisible ? (panelContent.height + panelPadding * 2) : 0

    // 外观
    color: zenInk
    border.color: zenMist
    border.width: 1
    radius: panelRadius
    clip: true // height 收起时裁剪内容，形成“卷轴”效果
    opacity: systemPanelVisible ? 1 : 0

    // 卷轴展开动画：参数与 CenterPanel.qml 对齐
    Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

    // 拦截背景点击，防止穿透到底层关闭
    MouseArea {
        anchors.fill: parent
        propagateComposedEvents: false
        onPressed: function(mouse) { mouse.accepted = false }
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

            Item { width: parent.width; height: fontSection
                Text { text: "[ GPU_CORE ]"; font.pixelSize: fontSection; font.letterSpacing: 3; color: zenAsh; anchors.left: parent.left }Text { text: "⌜"; font.pixelSize: fontSection; color: zenMist; anchors.right: parent.right }
            }

            Item {
                width: parent.width; height: panelRowHeight
                Text {
                    id: gpuLabel
                    anchors.left: parent.left; text: "GPU"; font.pixelSize: fontSecondary; color: zenSmoke
                }
                Text {
                    anchors.left: gpuLabel.right; anchors.right: parent.right
                    anchors.leftMargin: panelGap
                    text: gpuInfo; font.pixelSize: fontSecondary; color: zenCloud
                    horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                }
            }
        }

        Text { x: panelPadding; width: parent.width - panelPadding * 2; text: "─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─"; font.pixelSize: fontTiny; color: zenMist; horizontalAlignment: Text.AlignHCenter; clip: true }

        // ===== 盒子2: STORAGE =====
        Column {
            x: panelPadding
            width: parent.width - panelPadding * 2
            spacing: panelRowGap

            Item { width: parent.width; height: fontSection
                Text { text: "[ DISK_IO ]"; font.pixelSize: fontSection; font.letterSpacing: 3; color: zenAsh; anchors.left: parent.left }
                Text { text: "⌜"; font.pixelSize: fontSection; color: zenMist; anchors.right: parent.right }
            }

            Item {
                width: parent.width; height: panelRowHeight
                Text {
                    id: nvmeLabel
                    text: "NVME"; font.pixelSize: fontSecondary; color: zenSmoke
                    width: panelLabelWidth * 0.5; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: nvmeValue
                    text: nvmeUsage; font.pixelSize: fontSecondary; color: zenCloud
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
                    font.pixelSize: fontSecondary
                    font.family: "JetBrainsMono Nerd Font"
                    color: zenCloud
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Text { x: panelPadding; width: parent.width - panelPadding * 2; text: "─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─"; font.pixelSize: fontTiny; color: zenMist; horizontalAlignment: Text.AlignHCenter; clip: true }

        // ===== 盒子3: PERFORMANCE =====
        Column {
            x: panelPadding
            width: parent.width - panelPadding * 2
            spacing: panelRowGap

            Item { width: parent.width; height: fontSection
                Text { text: "[ PROC_MON ]"; font.pixelSize: fontSection; font.letterSpacing: 3; color: zenAsh; anchors.left: parent.left }
                Text { text: "⌜"; font.pixelSize: fontSection; color: zenMist; anchors.right: parent.right }
            }

            Item {
                width: parent.width; height: panelRowHeight
                Text {
                    anchors.left: parent.left; text: "LOAD"; font.pixelSize: fontSecondary; color: zenSmoke
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.right: parent.right; text: loadAvg; font.pixelSize: fontSecondary; color: zenCloud
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item {
                width: parent.width; height: panelRowHeight
                Text {
                    anchors.left: parent.left; text: "PROCS"; font.pixelSize: fontSecondary; color: zenSmoke
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.right: parent.right; text: processCount.toString(); font.pixelSize: fontSecondary; color: zenCloud
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item {
                width: parent.width; height: panelRowHeight
                Text {
                    anchors.left: parent.left; text: "MEM"; font.pixelSize: fontSecondary; color: zenSmoke
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.right: parent.right; text: memUsed.toFixed(1) + "G / " + memTotal.toFixed(0) + "G"; font.pixelSize: fontSecondary; color: zenCloud
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Text { x: panelPadding; width: parent.width - panelPadding * 2; text: "─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─"; font.pixelSize: fontTiny; color: zenMist; horizontalAlignment: Text.AlignHCenter; clip: true }

        // ===== 盒子4: SYSTEM =====
        Column {
            x: panelPadding
            width: parent.width - panelPadding * 2
            spacing: panelRowGap

            Item { width: parent.width; height: fontSection
                Text { text: "[ SYS_INFO ]"; font.pixelSize: fontSection; font.letterSpacing: 3; color: zenAsh; anchors.left: parent.left }
                Text { text: "⌜"; font.pixelSize: fontSection; color: zenMist; anchors.right: parent.right }
            }

            Item {
                width: parent.width; height: panelRowHeight
                Text {
                    anchors.left: parent.left; text: "KERNEL"; font.pixelSize: fontSecondary; color: zenSmoke
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.right: parent.right; text: kernelVer; font.pixelSize: fontSecondary; color: zenCloud
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item {
                width: parent.width; height: panelRowHeight
                Text {
                    id: cpuLabel
                    anchors.left: parent.left; text: "CPU"; font.pixelSize: fontSecondary; color: zenSmoke
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.left: cpuLabel.right; anchors.right: parent.right
                    anchors.leftMargin: panelGap
                    text: cpuModel; font.pixelSize: fontSecondary; color: zenCloud
                    horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item {
                width: parent.width; height: panelRowHeight
                Text {
                    anchors.left: parent.left; text: "UPTIME"; font.pixelSize: fontSecondary; color: zenSmoke
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.right: parent.right; text: uptime; font.pixelSize: fontSecondary; color: zenCloud
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Item { width: 1; height: panelGap * 2 }
    }
}
