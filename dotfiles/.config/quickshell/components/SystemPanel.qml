import QtQuick

// 模块：SystemPanel（系统面板内容组件）
// 功能：承载“系统面板”UI（GPU/存储/负载/进程/内存/系统信息），由 shell.qml 创建 PanelWindow 后嵌入本组件。
// 数据来源：所有字段均由 shell.qml 注入（gpuInfo/nvmeUsage/loadAvg/...），本组件只负责展示与动画。
// 动画：复刻 CenterPanel 的“卷轴展开”逻辑：height 展开 + y 微调 + opacity 渐变
Rectangle {
    id: systemPanel

    required property var root // ShellRoot 引用（来自 shell.qml），保留以便未来扩展（例如格式化/工具函数）
    required property var systemPanelCloseTimer // 关闭缓冲期定时器引用（来自 shell.qml，用于动画结束后清理 closing 状态）

    property bool systemPanelVisible: false // 打开态标志：true 时展开并显示
    property bool systemPanelClosing: false // 关闭缓冲期标志：用于确保收起动画期间仍可见/可拦截点击

    // 布局参数（由 shell 注入）
    property real panelGap: 0 // 标签/值之间的水平间隔基准
    property real panelLabelWidth: 0 // 左侧标签区域宽度基准（保留字段，当前布局主要用 anchors 对齐）
    property real panelOffsetY: 0 // 面板相对顶栏的 Y 偏移
    property real panelPadding: 0 // 面板内边距
    property real panelRadius: 0 // 面板圆角半径
    property real panelWidth: 0 // 面板宽度
    property real barMarginSide: 0 // 顶栏左右边距（用于把系统面板贴到右侧但不贴边）
    property real panelSectionGap: 0 // 分区之间的垂直间隔
    property real panelRowGap: 0 // 分区内部相邻行的垂直间隔
    property real panelRowHeight: 0 // 分区内部单行高度

    // 字体参数（由 shell 注入）
    property real fontSecondary: 12 // 常规行文本字号
    property real fontSection: 11 // 分区标题字号
    property real fontTiny: 10 // 点线填充/分隔线字号

    // 系统信息字段（由 shell 注入）
    property string gpuInfo: "" // GPU 信息（lspci 摘要）
    property string nvmeUsage: "0%" // 根分区占用（百分比 + used/total 文本）
    property string loadAvg: "" // 1 分钟 load average
    property int processCount: 0 // 进程数量（粗略）
    property real memTotal: 0 // 总内存（GB）
    property real memUsed: 0 // 已用内存（GB）
    property string kernelVer: "" // 内核版本（uname -r）
    property string cpuModel: "" // CPU 型号（/proc/cpuinfo 摘要）
    property string uptime: "" // uptime 简化文本

    // 主题色（由 shell 注入；默认透明用于在缺参时不“炸眼”）
    property color zenVoid: "transparent" // 最深底色
    property color zenInk: "transparent" // 主背景色
    property color zenStone: "transparent" // 悬停底色（此组件基本不使用 hover）
    property color zenMist: "transparent" // 边框/分割线色
    property color zenAsh: "transparent" // 弱标题色
    property color zenSmoke: "transparent" // 弱文本色
    property color zenCloud: "transparent" // 中等文本色
    property color zenSnow: "transparent" // 高对比文本色
    property color zenPure: "transparent" // 备用亮色
    property color zenAccent: "transparent" // 强调色（此组件当前未使用）

    // 全局字体常量
    readonly property string monoFont: "JetBrainsMono Nerd Font" // 等宽字体：保证点线/对齐稳定

    // ASCII 进度条字符宽度：用于把“像素宽度”换算为“字符数量”
    TextMetrics {
        id: asciiBarCharMetrics
        font.family: monoFont
        font.pixelSize: fontSecondary
        text: "█"
    }

    // 点/线填充字符宽度：用于把“像素宽度”换算为“字符数量”（从而实现动态填充）
    TextMetrics {
        id: dotCharMetrics
        font.family: monoFont
        font.pixelSize: fontTiny
        text: "·"
    }
    TextMetrics {
        id: lineCharMetrics
        font.family: monoFont
        font.pixelSize: fontTiny
        text: "─"
    }
    TextMetrics {
        id: spaceCharMetrics
        font.family: monoFont
        font.pixelSize: fontTiny
        text: " "
    }

    z: 1
    x: parent ? (parent.width - panelWidth - barMarginSide) : 0 // 固定贴右：panelWidth + barMarginSide 控制右侧留白
    y: panelOffsetY + (systemPanelVisible ? 0 : -8) // 收起时略向上偏移，配合 height 动画
    width: panelWidth // 固定宽度（由 shell 统一定义）
    height: systemPanelVisible ? (panelContent.height + panelPadding * 2) : 0 // 展开时高度=内容高度+上下 padding；收起时为 0

    color: zenInk // 面板底色
    border.color: zenMist // 面板描边色
    border.width: 1 // 边框宽度（像素）
    radius: panelRadius // 圆角
    clip: true // 裁剪：收起时隐藏内部内容，避免溢出
    opacity: systemPanelVisible ? 1 : 0 // 展开/收起时渐隐渐现

    // 展开/收起动画：QML Behavior 绑定属性变化时自动播放
    Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

    // 吞掉面板内部点击：防止点击面板内容触发外层“点击空白关闭”逻辑
    MouseArea {
        anchors.fill: parent
        propagateComposedEvents: false
        onPressed: function(mouse) { mouse.accepted = false }
    }

    // 点线填充辅助函数
    function repeatToWidth(pattern, patternWidthPx, totalWidthPx) {
        // 把 pattern 重复到“足够长”，最终由 Text 的 clip 截断；适配面板宽度变化。
        var w = patternWidthPx
        if (!w || w <= 0) {
            // 兜底：避免 metrics 未就绪导致返回空（等宽字体下此估算足够稳定）
            w = fontTiny * 0.6
        }
        var n = Math.ceil(totalWidthPx / w) + 2
        if (n <= 0) return ""

        var out = ""
        for (var i = 0; i < n; i++) out += pattern
        return out
    }

    function dotFill(totalWidthPx) {
        return repeatToWidth("·", dotCharMetrics.width, totalWidthPx)
    }

    function lineFill(totalWidthPx) {
        // 保持原先“─ + 空格”的观感（更像终端分隔符），同时根据宽度动态生成
        return repeatToWidth("─ ", lineCharMetrics.width + spaceCharMetrics.width, totalWidthPx)
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

        Text { x: panelPadding; width: parent.width - panelPadding * 2; text: lineFill(width); font.pixelSize: fontTiny; font.family: monoFont; color: zenMist; horizontalAlignment: Text.AlignHCenter; clip: true }

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
                    anchors.leftMargin: 20; anchors.rightMargin: 20
                    text: {
                        var p = parseInt(nvmeUsage)
                        var pct = isNaN(p) ? 0 : Math.max(0, Math.min(100, p))
                        return root.getAsciiBarAuto(pct, width, asciiBarCharMetrics.width)
                    }
                    font.pixelSize: fontSecondary; font.family: monoFont; color: zenCloud
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    clip: true
                }
            }
        }

        Text { x: panelPadding; width: parent.width - panelPadding * 2; text: lineFill(width); font.pixelSize: fontTiny; font.family: monoFont; color: zenMist; horizontalAlignment: Text.AlignHCenter; clip: true }

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
                    text: dotFill(width); font.pixelSize: fontTiny; font.family: monoFont; color: zenMist
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
                    text: dotFill(width); font.pixelSize: fontTiny; font.family: monoFont; color: zenMist
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
                    text: dotFill(width); font.pixelSize: fontTiny; font.family: monoFont; color: zenMist
                    anchors.verticalCenter: parent.verticalCenter; clip: true
                }
                Text {
                    id: memValue; anchors.right: parent.right; text: memUsed.toFixed(1) + "G / " + memTotal.toFixed(0) + "G"; font.pixelSize: fontSecondary; font.family: monoFont; color: zenCloud
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Text { x: panelPadding; width: parent.width - panelPadding * 2; text: lineFill(width); font.pixelSize: fontTiny; font.family: monoFont; color: zenMist; horizontalAlignment: Text.AlignHCenter; clip: true }

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
                    text: dotFill(width); font.pixelSize: fontTiny; font.family: monoFont; color: zenMist
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
                    text: dotFill(width); font.pixelSize: fontTiny; font.family: monoFont; color: zenMist
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
