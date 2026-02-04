// 模块：CenterPanel（中心面板窗口）
// 功能：从 shell.qml 抽离的中心面板窗口（多屏 Variants + PanelWindow + 面板内容）。
// 说明：
// - 本文件由 shell.qml 中 "// ===== CENTER PANEL WINDOW =====" 标记块抽离而来。
// - 通过属性绑定从 shell.qml 注入状态/主题/尺寸/控制 Process/Timer 引用。

import Quickshell
import QtQuick

Variants {
    id: centerPanel

    // 外部对象引用（用于写回状态 / 执行控制命令 / 触发关闭缓冲计时）
    required property var root
    required property var volSetProc
    required property var briSetProc
    required property var centerPanelCloseTimer

    // 34 个属性绑定（由 shell.qml 注入）
    property var animEasing
    property int animSpeedNormal
    property real baseUnit
    property int brightnessPercent
    property string btStatus
    property bool centerPanelClosing
    property bool centerPanelVisible
    property real fontSecondary
    property real fontSection
    property real fontTiny
    property string mediaArtist
    property bool mediaPlaying
    property real mediaPosition
    property string mediaTitle
    property var mprisPlayer
    property string netInterface
    property string netSSID
    property real panelGap
    property real panelLabelWidth
    property real panelOffsetY
    property real panelPadding
    property real panelRadius
    property real panelRowHeight
    property real panelWidth
    property real sliderHeight
    property real sliderHitArea
    property real sliderWidth
    property int volumePercent
    property color zenAsh
    property color zenCloud
    property color zenInk
    property color zenMist
    property color zenSmoke
    property color zenSnow
    model: Quickshell.screens // 多屏支持：为每个 screen 创建一套“中心面板”窗口（全屏透明层 + 居中面板）
    delegate: Component {
        PanelWindow {
            id: panelWindow
            required property var modelData // Variants 委托注入：当前 screen 对象
            screen: modelData // 将窗口绑定到当前屏幕
            visible: centerPanelVisible || centerPanelClosing // 可见条件：打开或处于关闭动画缓冲期
            exclusiveZone: -1 // 不占用布局保留区（允许窗口覆盖全屏）
            anchors { top: true; bottom: true; left: true; right: true } // 覆盖全屏：用于捕获“点击外部关闭”
            color: "transparent" // 窗口透明：只显示面板本体

            // 底层：点击外部关闭
            MouseArea {
                z: 0 // 底层：在面板之下，用于捕获空白处点击
                anchors.fill: parent // 覆盖整个窗口（全屏）
                onClicked: {
                    if (centerPanelVisible) {
                        root.centerPanelClosing = true // 进入关闭缓冲期（让动画/事件有时间完成）
                        root.centerPanelVisible = false // 关闭面板“打开态”
                        centerPanelCloseTimer.start() // 启动定时器：动画结束后清除 closing 标志
                    }
                }
            }

            // 上层：Panel 内容
            Rectangle {
                id: panelBg
                z: 1 // 上层：实际可见的面板本体
                x: (panelWindow.width - panelWidth) / 2 // 面板水平居中
                y: panelOffsetY // 面板距顶部偏移（与顶栏保持视觉间距）
                width: panelWidth // 面板固定宽度
                height: panelContent.height + panelPadding * 2 // 面板高度 = 内容高度 + 上下内边距
                color: zenInk // 面板背景色
                border.color: zenMist // 面板边框色
                border.width: 1 // 面板边框宽度
                radius: panelRadius // 面板圆角
                opacity: centerPanelVisible ? 1 : 0 // 透明度：用淡入淡出做开关动画
                Behavior on opacity { NumberAnimation { duration: animSpeedNormal; easing.type: animEasing } } // 透明度动画

                // 拦截背景点击，防止穿透到底层关闭
                MouseArea {
                    anchors.fill: parent // 覆盖面板本体区域
                    propagateComposedEvents: false // 不传播 composed events（减少“穿透”概率）
                    onPressed: function(mouse) { mouse.accepted = false } // 不吞掉 press：让内部控件（滑块/按钮）仍可响应；空白处可能仍被底层关闭层捕获
                }

                Column {
                    id: panelContent
                    anchors.top: parent.top // 内容从面板顶部开始布局
                    anchors.topMargin: panelPadding // 顶部内边距
                    anchors.left: parent.left // 左对齐
                    anchors.right: parent.right // 右对齐（撑满宽度）
                    spacing: panelGap // 行间距（统一控制视觉密度）

                    // CONNECTIVITY
                    Text { x: panelPadding; text: "CONNECTIVITY"; font.pixelSize: fontSection; font.letterSpacing: 3; color: zenAsh } // 分区标题：连接性
                    Row {
                        x: panelPadding; width: parent.width - panelPadding * 2 // 对齐并预留左右内边距
                        Text { text: "NETWORK"; font.pixelSize: fontSecondary; color: zenSmoke; width: panelLabelWidth } // 标签：网络
                        Text { text: netSSID; font.pixelSize: fontSecondary; color: zenCloud } // 值：SSID/Disconnected
                    }
                    Row {
                        x: panelPadding; width: parent.width - panelPadding * 2 // 与上一行对齐
                        Text { text: "INTERFACE"; font.pixelSize: fontSecondary; color: zenSmoke; width: panelLabelWidth } // 标签：网卡接口
                        Text { text: netInterface; font.pixelSize: fontSecondary; color: zenCloud } // 值：接口名（当前为静态占位）
                    }
                    Row {
                        x: panelPadding; width: parent.width - panelPadding * 2 // 与上一行对齐
                        Text { text: "BLUETOOTH"; font.pixelSize: fontSecondary; color: zenSmoke; width: panelLabelWidth } // 标签：蓝牙
                        Text { text: "archshiyi - " + btStatus; font.pixelSize: fontSecondary; color: zenCloud } // 值：蓝牙电源状态（示例前缀 + ON/OFF）
                    }
                    Rectangle { x: panelPadding; width: parent.width - panelPadding * 2; height: 1; color: zenMist } // 分割线

                    // AUDIO / DISPLAY
                    Text { x: panelPadding; text: "AUDIO / DISPLAY"; font.pixelSize: fontSection; font.letterSpacing: 3; color: zenAsh } // 分区标题：音频/显示
                    Row {
                        x: panelPadding; width: parent.width - panelPadding * 2; spacing: panelGap * 3; height: panelRowHeight // 一行：音量
                        Text { text: "VOL"; font.pixelSize: fontSecondary; color: zenSmoke; width: panelLabelWidth * 0.5; anchors.verticalCenter: parent.verticalCenter } // 标签：音量
                        Rectangle {
                            clip: false // 不裁剪：允许点击热区 margins 扩展到外侧
                            width: sliderWidth; height: sliderHeight; color: zenMist; anchors.verticalCenter: parent.verticalCenter // 进度条背景
                            Rectangle { width: parent.width * Math.min(volumePercent / 100, 1.0); height: sliderHeight; color: zenCloud } // 进度条填充（0~100）
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -sliderHitArea; cursorShape: Qt.PointingHandCursor // 扩大点击热区并提示可点击
                                onClicked: mouse => {
                                    let pct = Math.min(Math.round(mouse.x / parent.width * 100), 100) // 点击位置映射到 0~100，并限制最大 100
                                    let vol = (pct / 100).toFixed(2)  // 把百分比转为 0.00~1.00（wpctl 需要）
                                    volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", vol] // 组装设置音量命令
                                    volSetProc.running = true // 异步执行设置音量
                                    root.volumePercent = pct // 立即更新 UI（不等待命令回写）
                                }
                            }
                        }
                        Text { text: volumePercent + "%"; font.pixelSize: fontSecondary; color: zenCloud; width: panelLabelWidth * 0.6; anchors.verticalCenter: parent.verticalCenter } // 音量数值
                    }
                    Row {
                        x: panelPadding; width: parent.width - panelPadding * 2; spacing: panelGap * 3; height: panelRowHeight // 一行：亮度
                        Text { text: "BRI"; font.pixelSize: fontSecondary; color: zenSmoke; width: panelLabelWidth * 0.5; anchors.verticalCenter: parent.verticalCenter } // 标签：亮度
                        Rectangle {
                            width: sliderWidth; height: sliderHeight; color: zenMist; anchors.verticalCenter: parent.verticalCenter // 进度条背景
                            Rectangle { width: parent.width * brightnessPercent / 100; height: sliderHeight; color: zenCloud } // 进度条填充（0~100）
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -sliderHitArea; cursorShape: Qt.PointingHandCursor // 扩大点击热区并提示可点击
                                onClicked: mouse => {
                                    let pct = Math.round(mouse.x / parent.width * 100) // 点击位置映射到 0~100
                                    briSetProc.command = ["brightnessctl", "set", pct + "%"] // 组装设置亮度命令
                                    briSetProc.running = true // 异步执行设置亮度
                                    root.brightnessPercent = pct // 立即更新 UI（不等待命令回写）
                                }
                            }
                        }
                        Text { text: brightnessPercent + "%"; font.pixelSize: fontSecondary; color: zenCloud; width: panelLabelWidth * 0.6; anchors.verticalCenter: parent.verticalCenter } // 亮度数值
                    }
                    Rectangle { x: panelPadding; width: parent.width - panelPadding * 2; height: 1; color: zenMist } // 分割线

                    // NOW PLAYING
                    Text { x: panelPadding; text: "NOW PLAYING"; font.pixelSize: fontSection; font.letterSpacing: 3; color: zenAsh } // 分区标题：媒体播放
                    Row {
                        x: panelPadding; width: parent.width - panelPadding * 2; height: baseUnit * 1.8; spacing: panelGap * 4 // 一行：媒体信息 + 控制按钮
                        Column {
                            width: parent.width - baseUnit * 4; anchors.verticalCenter: parent.verticalCenter; spacing: 2 // 左侧信息区（右侧预留按钮空间）
                            Text { text: mediaTitle; font.pixelSize: fontSecondary * 1.1; color: zenSnow; width: parent.width; elide: Text.ElideRight } // 标题（过长省略）
                            Text {
                                text: root.formatTime(mediaPosition) + " / " + root.formatTime(mprisPlayer?.length ?? 0) // 进度：当前位置 / 总时长（总时长缺失则 00:00）
                                font.pixelSize: fontTiny; color: zenCloud // 辅助信息字号与颜色
                            }
                            Text { text: mediaArtist; font.pixelSize: fontTiny; color: zenSmoke } // 艺术家（弱化显示）
                        }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter; spacing: panelGap * 2.5 // 右侧按钮组
                            Repeater {
                                model: ["prev", "play", "next"] // 三个按钮：上一首/播放暂停/下一首
                                Rectangle {
                                    width: baseUnit * 1.1; height: baseUnit * 1.1; color: "transparent"; radius: 2 // 按钮容器（透明背景）
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData === "prev" ? "⏮" : (modelData === "next" ? "⏭" : (mediaPlaying ? "⏸" : "▶")) // 根据按钮类型与播放状态选择图标
                                        font.pixelSize: fontSecondary; color: zenSmoke // 图标字号与颜色
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor // 点击热区覆盖按钮并提示可点击
                                        onClicked: {
                                            if (mprisPlayer) { // 只有在存在播放器时才执行控制
                                                if (modelData === "prev") mprisPlayer.previous() // 上一首
                                                else if (modelData === "next") mprisPlayer.next() // 下一首
                                                else mprisPlayer.togglePlaying() // 播放/暂停切换
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Item { width: 1; height: panelGap * 2 } // 底部留白（避免内容贴边）
                }
            }
        }
    }
}
