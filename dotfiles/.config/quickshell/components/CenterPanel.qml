import QtQuick

// 模块：CenterPanel（中心面板内容组件）
// 功能：承载“中心面板”UI（网络/蓝牙/音量/亮度/媒体控制），由 shell.qml 创建 PanelWindow 后嵌入本组件。
// 交互模型：
// - 可见性由 shell 注入的 centerPanelVisible/centerPanelClosing 驱动（展开/收起动画）
// - 所有“读数据”字段来自 shell 的属性注入（netSSID/btStatus/volumePercent/...）
// - 所有“写控制”动作通过 root 暴露的方法完成（root.setVolume/root.setBrightness/MPRIS 控制等）
// 动画：复刻旧实现的“卷轴展开”逻辑：height 展开 + y 微调 + opacity 渐变
Rectangle {
    id: centerPanel

    required property var root // ShellRoot 引用（来自 shell.qml），提供 getAsciiBar/formatTime/setVolume/setBrightness 等能力
    required property var centerPanelCloseTimer // 关闭缓冲期定时器引用（来自 shell.qml，用于动画结束后清理 closing 状态）

    // 动画参数（由 shell 注入，统一风格/时长；此组件内部仅消费）
    property var animEasing // 缓动曲线（当前实现的 Behavior 里使用固定 easing，可留作未来统一化）
    property int animSpeedNormal // 常规动画时长（ms；当前 Behavior 使用固定值，可用于未来替换）

    // 尺寸基准（由 shell 注入）
    property real baseUnit // 全局尺寸基准（用于控制面板内部控件尺度）

    // 面板数据（由 shell 注入，驱动显示）
    property int brightnessPercent // 亮度百分比（0~100）
    property string btStatus // 蓝牙电源状态（ON/OFF）
    property bool centerPanelClosing // 关闭缓冲期标志：用于确保收起动画期间仍可见/可拦截点击
    property bool centerPanelVisible // 打开态标志：true 时展开并显示
    property real fontSecondary // 常规行文本字号
    property real fontSection // 分区标题字号
    property real fontTiny // 点线填充/分隔线字号
    property string mediaArtist // 媒体艺术家字符串
    property bool mediaPlaying // 是否播放态（控制 play/pause 图标）
    property real mediaPosition // 当前播放位置（秒）
    property string mediaTitle // 媒体标题（为 "No Media" 时隐藏媒体区）
    property var mprisPlayer // 当前选中的 MPRIS 播放器对象（可调用 previous/next/togglePlaying）
    property string netInterface // 网络接口名（展示用）
    property string netSSID // 当前网络 SSID（或 Disconnected）

    // 布局参数（由 shell 注入）
    property real panelGap // 标签/值之间的水平间隔基准
    property real panelLabelWidth // 左侧标签区域宽度基准（便于对齐）
    property real panelOffsetY // 面板相对顶栏的 Y 偏移
    property real panelPadding // 面板内边距
    property real panelRadius // 面板圆角半径
    property real panelRowGap // 面板内部相邻行的垂直间隔
    property real panelRowHeight // 面板单行高度（滑条/数据行）
    property real panelSectionGap // 分区之间的垂直间隔
    property real panelWidth // 面板宽度
    property real sliderHeight // 滑条高度（此版本使用字符条；保留参数以便未来换成真实 Slider）
    property real sliderHitArea // 滑条点击热区扩展（像素；便于小尺寸操作）

    // 控制变量（由 shell 注入）
    property int volumePercent // 音量百分比（0~100）

    // 主题色（由 shell 注入）
    property color zenAsh // 弱标题/辅助色
    property color zenCloud // 中等对比文本色
    property color zenInk // 面板背景色
    property color zenMist // 边框/分割线色
    property color zenSmoke // 弱文本色
    property color zenSnow // 高对比文本色

    property real panelX: 0 // 面板 X 坐标（由 shell 计算：对齐到 CenterIsland 中心）

    readonly property string monoFont: "JetBrainsMono Nerd Font" // 等宽字体：确保 ASCII 进度条/点线对齐

    // 统一的“留白”像素常量（避免在子项里直接引用未限定标识符导致 ReferenceError）
    readonly property int leaderGapPx: 3 // 点线填充距离左右文字的空白
    readonly property int sepGapPx: 3 // 分隔线左右空白
    readonly property int sliderGapPx: 20 // 进度条距离左右文字的空白

    // SYS_IO 标签补齐：让不同标签长度的行拥有相同的“进度条可用宽度”
    readonly property string _padChar: "\u00A0" // 不换行空格（不可见，占位用）
    readonly property int sysIoLabelChars: Math.max("MASTER_GAIN".length, "BACKLIGHT".length)
    function padSysIoLabel(s) {
        var pad = sysIoLabelChars - s.length
        if (pad <= 0) return s
        return s + Array(pad + 1).join(_padChar)
    }

    // ASCII 进度条字符宽度：用于把“像素宽度”换算为“字符数量”
    TextMetrics {
        id: asciiBarCharMetrics
        font.family: monoFont
        font.pixelSize: fontSecondary
        text: "█"
    }

    z: 1
    x: panelX // 位置：由 shell 计算并注入
    y: panelOffsetY + (centerPanelVisible ? 0 : -8) // 收起时略向上偏移，配合 height 动画更像“卷起”
    width: panelWidth // 固定宽度（由 shell 统一定义）
    height: centerPanelVisible ? (panelContent.height + panelPadding * 2) : 0 // 展开时高度=内容高度+上下 padding；收起时为 0
    opacity: centerPanelVisible ? 1 : 0 // 展开/收起时渐隐渐现
    color: zenInk // 面板底色
    border.color: zenMist // 面板描边色
    border.width: 1 // 边框宽度（像素）
    radius: panelRadius // 圆角
    clip: true // 裁剪：收起时隐藏内部内容，避免溢出

    // 展开/收起动画：QML Behavior 绑定属性变化时自动播放
    Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

    // 吞掉面板内部点击：防止点击面板内容触发外层“点击空白关闭”逻辑
    MouseArea {
        anchors.fill: parent
        onPressed: function(mouse) { mouse.accepted = true }
        onClicked: function(mouse) { mouse.accepted = true }
    }

    Column {
        id: panelContent
        anchors.top: parent.top
        anchors.topMargin: panelPadding
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: panelSectionGap

        // ===== 盒子1: CONNECTIVITY =====
        Column {
            x: panelPadding
            width: parent.width - panelPadding * 2
            spacing: panelRowGap

            TextMetrics {
                id: leaderDotMetrics
                font.family: monoFont
                font.pixelSize: fontTiny
                text: "·"
            }

            Item {
                width: parent.width; height: fontSection
                Text { text: "[ NET_IO ]"; font.pixelSize: fontSection; font.letterSpacing: 3; font.family: monoFont; color: zenAsh; anchors.left: parent.left }
                Text { text: "⌜"; font.pixelSize: fontSection; font.family: monoFont; color: zenMist; anchors.right: parent.right }
            }

            Item {
                width: parent.width; height: fontSecondary
                Text {
                    id: ifLabel; anchors.left: parent.left; text: "INTERFACE"; font.pixelSize: fontSecondary; font.family: monoFont; color: zenSmoke
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.left: ifLabel.right; anchors.right: ifValue.left
                    anchors.leftMargin: centerPanel.leaderGapPx; anchors.rightMargin: centerPanel.leaderGapPx
                    text: Array(Math.max(0, Math.floor(width / Math.max(1, leaderDotMetrics.width))) + 1).join("·")
                    font.pixelSize: fontTiny; font.family: monoFont; color: zenMist
                    anchors.verticalCenter: parent.verticalCenter; clip: true
                }
                Text {
                    id: ifValue; anchors.right: parent.right; text: netSSID; font.pixelSize: fontSecondary; font.family: monoFont; color: zenCloud
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item {
                width: parent.width; height: fontSecondary
                Text {
                    id: adLabel; anchors.left: parent.left; text: "ADAPTER"; font.pixelSize: fontSecondary; font.family: monoFont; color: zenSmoke
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.left: adLabel.right; anchors.right: adValue.left
                    anchors.leftMargin: centerPanel.leaderGapPx; anchors.rightMargin: centerPanel.leaderGapPx
                    text: Array(Math.max(0, Math.floor(width / Math.max(1, leaderDotMetrics.width))) + 1).join("·")
                    font.pixelSize: fontTiny; font.family: monoFont; color: zenMist
                    anchors.verticalCenter: parent.verticalCenter; clip: true
                }
                Text {
                    id: adValue; anchors.right: parent.right; text: netInterface; font.pixelSize: fontSecondary; font.family: monoFont; color: zenCloud
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item {
                width: parent.width; height: fontSecondary
                Text {
                    id: btLabel; anchors.left: parent.left; text: "BLUETOOTH"; font.pixelSize: fontSecondary; font.family: monoFont; color: zenSmoke
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.left: btLabel.right; anchors.right: btValue.left
                    anchors.leftMargin: centerPanel.leaderGapPx; anchors.rightMargin: centerPanel.leaderGapPx
                    text: Array(Math.max(0, Math.floor(width / Math.max(1, leaderDotMetrics.width))) + 1).join("·")
                    font.pixelSize: fontTiny; font.family: monoFont; color: zenMist
                    anchors.verticalCenter: parent.verticalCenter; clip: true
                }
                Text {
                    id: btValue; anchors.right: parent.right; text: "archshiyi - " + btStatus; font.pixelSize: fontSecondary; font.family: monoFont; color: zenCloud
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Item {
            x: panelPadding
            width: parent.width - panelPadding * 2

            // 分隔线：按可用宽度动态生成，左右预留 3px 空白
            TextMetrics {
                id: sepDashMetrics
                font.family: monoFont
                font.pixelSize: fontTiny
                text: "─ "
            }

            Text {
                id: sepLine
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: centerPanel.sepGapPx
                anchors.rightMargin: centerPanel.sepGapPx
                text: Array(Math.max(0, Math.floor(width / Math.max(1, sepDashMetrics.width))) + 1).join("─ ")
                font.pixelSize: fontTiny; font.family: monoFont; color: zenMist
                horizontalAlignment: Text.AlignHCenter
                clip: true
            }

            height: sepLine.implicitHeight
        }

        // ===== 盒子2: AUDIO / DISPLAY =====
        Column {
            x: panelPadding
            width: parent.width - panelPadding * 2
            spacing: panelRowGap

            Item {
                width: parent.width; height: fontSection
                Text { text: "[ SYS_IO ]"; font.pixelSize: fontSection; font.letterSpacing: 3; font.family: monoFont; color: zenAsh; anchors.left: parent.left }
                Text { text: "⌜"; font.pixelSize: fontSection; font.family: monoFont; color: zenMist; anchors.right: parent.right }
            }

            // 音量行
            Item {
                width: parent.width; height: panelRowHeight
                Text {
                    id: volLabel
                    text: centerPanel.padSysIoLabel("MASTER_GAIN"); font.pixelSize: fontSecondary; font.family: monoFont; color: zenSmoke
                    // 允许标签区域按需扩展，避免“标签溢出覆盖进度条”；同时保留对齐基准
                    width: Math.max(panelLabelWidth * 0.5, implicitWidth)
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: volValue
                    text: volumePercent + "%"; font.pixelSize: fontSecondary; font.family: monoFont; color: zenCloud
                    width: panelLabelWidth * 0.8; anchors.right: parent.right; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: volSlider
                    anchors.left: volLabel.right; anchors.right: volValue.left
                    anchors.leftMargin: centerPanel.sliderGapPx; anchors.rightMargin: centerPanel.sliderGapPx
                    text: root.getAsciiBarAuto(volumePercent, width, asciiBarCharMetrics.width) // 按可用宽度动态生成
                    font.pixelSize: fontSecondary; font.family: monoFont; color: zenCloud
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    clip: true

                    MouseArea {
                        anchors.fill: parent; anchors.margins: -sliderHitArea; cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            let pct = Math.min(Math.round(mouse.x / volSlider.width * 100), 100)
                            root.setVolume(pct) // 把点击位置映射为 0~100% 音量，并委托 shell 执行设置
                        }
                    }
                }
            }

            // 亮度行
            Item {
                width: parent.width; height: panelRowHeight
                Text {
                    id: briLabel
                    text: centerPanel.padSysIoLabel("BACKLIGHT"); font.pixelSize: fontSecondary; font.family: monoFont; color: zenSmoke
                    // 允许标签区域按需扩展，避免“标签溢出覆盖进度条”；同时保留对齐基准
                    width: Math.max(panelLabelWidth * 0.5, implicitWidth)
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: briValue
                    text: brightnessPercent + "%"; font.pixelSize: fontSecondary; font.family: monoFont; color: zenCloud
                    width: panelLabelWidth * 0.8; anchors.right: parent.right; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: briSlider
                    anchors.left: briLabel.right; anchors.right: briValue.left
                    anchors.leftMargin: centerPanel.sliderGapPx; anchors.rightMargin: centerPanel.sliderGapPx
                    text: root.getAsciiBarAuto(brightnessPercent, width, asciiBarCharMetrics.width) // 按可用宽度动态生成
                    font.pixelSize: fontSecondary; font.family: monoFont; color: zenCloud
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    clip: true

                    MouseArea {
                        anchors.fill: parent; anchors.margins: -sliderHitArea; cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            let pct = Math.round(mouse.x / briSlider.width * 100)
                            root.setBrightness(pct) // 把点击位置映射为 0~100% 亮度，并委托 shell 执行设置
                        }
                    }
                }
            }
        }

        Item {
            x: panelPadding
            width: parent.width - panelPadding * 2
            visible: mediaTitle !== "No Media" && mediaTitle !== ""

            // 分隔线：按可用宽度动态生成，左右预留 3px 空白（仅媒体区可见时显示）
            TextMetrics {
                id: sepDashMetricsMedia
                font.family: monoFont
                font.pixelSize: fontTiny
                text: "─ "
            }

            Text {
                id: sepLineMedia
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: centerPanel.sepGapPx
                anchors.rightMargin: centerPanel.sepGapPx
                text: Array(Math.max(0, Math.floor(width / Math.max(1, sepDashMetricsMedia.width))) + 1).join("─ ")
                font.pixelSize: fontTiny; font.family: monoFont; color: zenMist
                horizontalAlignment: Text.AlignHCenter
                clip: true
            }

            height: visible ? sepLineMedia.implicitHeight : 0
            clip: true
        }

        // ===== 盒子3: NOW PLAYING =====
        Column {
            x: panelPadding
            width: parent.width - panelPadding * 2
            spacing: panelRowGap
            visible: mediaTitle !== "No Media" && mediaTitle !== ""

            Item {
                width: parent.width; height: fontSection
                Text { text: "// MEDIA_STREAM"; font.pixelSize: fontSection; font.letterSpacing: 3; font.family: monoFont; color: zenAsh; anchors.left: parent.left }
                Text { text: "⌜"; font.pixelSize: fontSection; font.family: monoFont; color: zenMist; anchors.right: parent.right }
            }

            Row {
                width: parent.width; height: baseUnit * 1.8; spacing: panelGap * 4
                Column {
                    width: parent.width - baseUnit * 4; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                    Text { text: mediaTitle; font.pixelSize: fontSecondary * 1.1; font.family: monoFont; color: zenSnow; width: parent.width; elide: Text.ElideRight }
                    Text {
                        text: root.formatTime(mediaPosition) + " / " + root.formatTime(mprisPlayer?.length ?? 0) // 当前位置/总时长（MM:SS）
                        font.pixelSize: fontTiny; font.family: monoFont; color: zenCloud
                    }
                    Text { text: mediaArtist; font.pixelSize: fontTiny; font.family: monoFont; color: zenSmoke }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter; spacing: panelGap * 2.5
                    Repeater {
                        model: ["prev", "play", "next"]
                        Rectangle {
                            width: baseUnit * 1.1; height: baseUnit * 1.1; color: "transparent"; radius: 2
                            Text {
                                anchors.centerIn: parent
                                text: modelData === "prev" ? "⏮" : (modelData === "next" ? "⏭" : (mediaPlaying ? "⏸" : "▶"))
                                font.pixelSize: fontSecondary; font.family: monoFont; color: zenSmoke
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (mprisPlayer) {
                                        if (modelData === "prev") mprisPlayer.previous()
                                        else if (modelData === "next") mprisPlayer.next()
                                        else mprisPlayer.togglePlaying()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item { width: 1; height: panelGap * 2 }
    }
}
