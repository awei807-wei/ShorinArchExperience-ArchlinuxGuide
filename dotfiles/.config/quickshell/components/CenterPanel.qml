// 模块：CenterPanel（中心弹出面板）
// 功能：展示并控制常用状态（网络/蓝牙/音量/亮度/媒体）。
// 说明：
// - 本文件实现的是“面板内容组件”，可被 shell.qml 的 PanelWindow 容器引用。
// - 当前仓库的 shell.qml 可能使用“内联面板 UI”（直接在 shell.qml 写 Rectangle/Column），
//   因此该组件可能处于未被引用的状态；但保留它有利于未来把面板 UI 组件化。
// 数据来源（通过外部命令采集）：
// - 网络：nmcli
// - 蓝牙：bluetoothctl
// - 音量：wpctl（注意：此文件使用 0-200 的百分比刻度）
// - 亮度：brightnessctl
// - 媒体：playerctl（标题/艺术家/播放状态 + 上一首/播放暂停/下一首）
// 注意：
// - 该组件会主动刷新（Component.onCompleted）并提供 refreshData() 供外部按需刷新。
// - 本组件的命令执行都是“异步 Process”，UI 通过属性绑定更新。

import QtQuick // QML 基础类型（Item/Rectangle/Text/MouseArea 等）
import QtQuick.Layouts // 目前主要用于布局类型导入（便于未来扩展）
import Quickshell // 运行时基础
import Quickshell.Io // Process/SplitParser：执行外部命令并解析输出

Item {
    id: panelRoot
    property real unit: 24 // 尺寸基准（由外部注入；用于统一缩放）
    property color zenInk: "#141414" // 背景色
    property color zenMist: "#2a2a2a" // 边框/分割线色
    property color zenStone: "#1f1f1f" // hover 背景色（本组件主要用于拦截层，较少用）
    property color zenAsh: "#3a3a3a" // 弱对比色（分区标题）
    property color zenSmoke: "#5a5a5a" // 弱文本色（标签）
    property color zenCloud: "#8a8a8a" // 中等文本色（数值）
    property color zenSnow: "#cacaca" // 高对比文本色（主要信息）

    property string netSSID: "loading..." // 当前连接的 Wi-Fi SSID（或 Disconnected）
    property string btStatus: "OFF" // 蓝牙电源状态（ON/OFF）
    property int volumePercent: 70 // 音量百分比（0-200；此文件用 200 作为“最大”刻度）
    property int brightnessPercent: 50 // 亮度百分比（0-100）
    property string mediaTitle: "No Media" // 当前播放曲目标题
    property string mediaArtist: "--" // 当前播放曲目艺术家
    property bool mediaPlaying: false // 是否处于播放态（用于显示播放/暂停图标）

    implicitWidth: unit * 22 // 面板默认宽度（供外部布局计算）
    implicitHeight: panelContent.height + unit * 1.0 // 面板默认高度 = 内容高度 + 上下留白

    function refreshData() {
        // 输入：无
        // 输出：无返回值
        // 副作用：启动各个 Process 以刷新面板展示数据
        // 触发来源：Component.onCompleted 自动触发；也可由外部在面板展开时按需调用

        netProc.running = true // 刷新网络 SSID
        btProc.running = true // 刷新蓝牙状态
        volProc.running = true // 刷新音量百分比
        briProc.running = true // 刷新亮度百分比
        mediaProc.running = true // 刷新媒体元数据/播放状态
    }

    Component.onCompleted: refreshData() // 组件加载完成后立即刷新一次，避免显示占位值

    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2 || echo 'Disconnected'"] // 取当前激活 Wi-Fi 的 SSID
        stdout: SplitParser { onRead: data => panelRoot.netSSID = data.trim() || "Disconnected" } // 写回状态（驱动 UI）
    }
    Process {
        id: btProc
        command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo 'ON' || echo 'OFF'"] // 判断蓝牙电源是否开启
        stdout: SplitParser { onRead: data => panelRoot.btStatus = data.trim() } // 写回 ON/OFF
    }
    Process {
        id: volProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*200)}'"] // 把 0.0~1.0 映射到 0~200（支持 >100%）
        stdout: SplitParser { onRead: data => panelRoot.volumePercent = parseInt(data) || 0 } // 解析并写回音量百分比
    }
    Process {
        id: briProc
        command: ["sh", "-c", "brightnessctl -m | cut -d, -f4 | tr -d '%' 2>/dev/null || echo 50"] // 读亮度百分比（失败则回退 50）
        stdout: SplitParser { onRead: data => panelRoot.brightnessPercent = parseInt(data) || 50 } // 解析并写回亮度百分比
    }
    Process {
        id: mediaProc
        command: ["sh", "-c", "playerctl metadata --format '{{title}}|||{{artist}}|||{{status}}' 2>/dev/null || echo 'No Media|||--|||Stopped'"] // 拉取媒体元数据与播放状态
        stdout: SplitParser {
            onRead: data => {
                let parts = data.split("|||") // 用自定义分隔符拆分三段：title / artist / status
                panelRoot.mediaTitle = parts[0] || "No Media" // 标题为空则回退
                panelRoot.mediaArtist = parts[1] || "--" // 艺术家为空则回退
                panelRoot.mediaPlaying = (parts[2] === "Playing") // status=Playing 表示播放态，否则视为暂停/停止
            }
        }
    }

    Process { id: volSetProc; command: ["echo"] } // 占位：点击音量条时替换为 wpctl set-volume
    Process { id: briSetProc; command: ["echo"] } // 占位：点击亮度条时替换为 brightnessctl set
    Process { id: mediaPrevProc; command: ["playerctl", "previous"] } // 媒体控制：上一首
    Process { id: mediaPlayProc; command: ["playerctl", "play-pause"] } // 媒体控制：播放/暂停切换
    Process { id: mediaNextProc; command: ["playerctl", "next"] } // 媒体控制：下一首
    Process { id: matugenProc; command: ["sh", "-c", "matugen image ~/.config/wallpaper.jpg"] } // 主题生成（示例；未在 UI 中直接触发）
    Process { id: reloadProc; command: ["echo", "QuickShell: Reload ignored, using hot-reload."] } // 旧逻辑占位：提示不再需要 reload

    Rectangle {
        id: panelBg
        anchors.fill: parent // 背景覆盖整个组件
        color: zenInk; border.color: zenMist; border.width: 1; radius: 2 // 背景色 + 边框 + 圆角（保持岛屿风格一致）

        // 拦截层
        MouseArea {
            anchors.fill: parent // 拦截层覆盖整个面板
            propagateComposedEvents: false // 不让事件穿透到下层（避免点击触发“关闭面板”的外层逻辑）
            onClicked: mouse => mouse.accepted = true // 明确吃掉点击事件
        }

        Column {
            id: panelContent
            anchors.top: parent.top; anchors.topMargin: unit * 0.5 // 顶部留白
            anchors.left: parent.left; anchors.right: parent.right // 左右填充
            spacing: unit * 0.15 // 行间距（较紧凑）

            Text { x: unit * 0.8; text: "CONNECTIVITY"; font.pixelSize: unit * 0.28; font.letterSpacing: 3; color: zenAsh } // 分区标题：连接性
            Row {
                x: unit * 0.8; width: parent.width - unit * 1.6 // 左右留白与标题对齐
                Text { text: "NETWORK"; font.pixelSize: unit * 0.35; color: zenSmoke; width: unit * 5 } // 标签
                Text { text: panelRoot.netSSID; font.pixelSize: unit * 0.35; color: zenCloud } // 值：SSID/Disconnected
            }
            Row {
                x: unit * 0.8; width: parent.width - unit * 1.6 // 与上一行对齐
                Text { text: "BLUETOOTH"; font.pixelSize: unit * 0.35; color: zenSmoke; width: unit * 5 } // 标签
                Text { text: "archshiyi · " + panelRoot.btStatus; font.pixelSize: unit * 0.35; color: zenCloud } // 值：状态（示例前缀 + ON/OFF）
            }

            Rectangle { x: unit * 0.8; width: parent.width - unit * 1.6; height: 1; color: zenMist } // 分割线

            Text { x: unit * 0.8; text: "AUDIO / DISPLAY"; font.pixelSize: unit * 0.28; font.letterSpacing: 3; color: zenAsh } // 分区标题：音频/显示
            Row {
                x: unit * 0.8; spacing: unit * 0.5; height: unit * 0.9 // 一行：音量条
                Text { text: "VOL"; font.pixelSize: unit * 0.35; color: zenSmoke; width: unit * 2.5; anchors.verticalCenter: parent.verticalCenter } // 标签
                Rectangle {
                    width: unit * 12; height: 3; color: zenMist; anchors.verticalCenter: parent.verticalCenter // 进度条背景
                    Rectangle { width: parent.width * Math.min(panelRoot.volumePercent / 200, 1.0); height: 3; color: zenCloud } // 填充条：按 0~200 映射
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -10; cursorShape: Qt.PointingHandCursor // 扩大点击热区并提示可点击
                        onClicked: mouse => {
                            let pct = Math.round(mouse.x / parent.width * 200) // 点击位置映射到 0~200
                            volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (pct / 200).toFixed(2)] // 转成 0.00~1.00
                            volSetProc.running = true // 异步执行设置音量
                            panelRoot.volumePercent = pct // 立即更新 UI（避免等待外部命令回写）
                            mouse.accepted = true // 吃掉事件，避免外层误触
                        }
                    }
                }
                Text { text: panelRoot.volumePercent + "%"; font.pixelSize: unit * 0.35; color: zenCloud; width: unit * 3; anchors.verticalCenter: parent.verticalCenter } // 数值显示（0~200%）
            }
            Row {
                x: unit * 0.8; spacing: unit * 0.5; height: unit * 0.9 // 一行：亮度条
                Text { text: "BRI"; font.pixelSize: unit * 0.35; color: zenSmoke; width: unit * 2.5; anchors.verticalCenter: parent.verticalCenter } // 标签
                Rectangle {
                    width: unit * 12; height: 3; color: zenMist; anchors.verticalCenter: parent.verticalCenter // 进度条背景
                    Rectangle { width: parent.width * panelRoot.brightnessPercent / 100; height: 3; color: zenCloud } // 填充条：按 0~100 映射
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -10; cursorShape: Qt.PointingHandCursor // 扩大点击热区并提示可点击
                        onClicked: mouse => {
                            let pct = Math.round(mouse.x / parent.width * 100) // 点击位置映射到 0~100
                            briSetProc.command = ["brightnessctl", "set", pct + "%"] // 组装亮度设置命令
                            briSetProc.running = true // 异步执行设置亮度
                            panelRoot.brightnessPercent = pct // 立即更新 UI（避免等待外部命令回写）
                            mouse.accepted = true // 吃掉事件，避免外层误触
                        }
                    }
                }
                Text { text: panelRoot.brightnessPercent + "%"; font.pixelSize: unit * 0.35; color: zenCloud; width: unit * 3; anchors.verticalCenter: parent.verticalCenter } // 数值显示（0~100%）
            }

            Rectangle { x: unit * 0.8; width: parent.width - unit * 1.6; height: 1; color: zenMist } // 分割线

            Text { x: unit * 0.8; text: "NOW PLAYING"; font.pixelSize: unit * 0.28; font.letterSpacing: 3; color: zenAsh } // 分区标题：正在播放
            Row {
                x: unit * 0.8; width: parent.width - unit * 1.6; height: unit * 1.8; spacing: unit * 0.6 // 一行：媒体信息 + 控制按钮
                Column {
                    width: parent.width - unit * 4; anchors.verticalCenter: parent.verticalCenter; spacing: 3 // 左侧信息区宽度预留给按钮
                    Text { text: panelRoot.mediaTitle; font.pixelSize: unit * 0.38; color: zenSnow; width: parent.width; elide: Text.ElideRight } // 标题（过长省略）
                    Text { text: panelRoot.mediaArtist; font.pixelSize: unit * 0.3; color: zenSmoke } // 艺术家
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter; spacing: unit * 0.4 // 右侧按钮组
                    Repeater {
                        model: ["prev", "play", "next"] // 三个按钮：上一首/播放暂停/下一首
                        Rectangle {
                            width: unit * 1.1; height: unit * 1.1; color: "transparent"; radius: 2 // 按钮容器（透明背景）
                            Text {
                                anchors.centerIn: parent
                                text: modelData === "prev" ? "⏮" : (modelData === "next" ? "⏭" : (panelRoot.mediaPlaying ? "⏸" : "▶")) // 根据按钮类型与播放状态选择图标
                                font.pixelSize: unit * 0.5; color: zenSmoke // 图标字号与颜色
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor // 点击热区覆盖按钮
                                onClicked: mouse => {
                                    if (modelData === "prev") mediaPrevProc.running = true // 上一首
                                    else if (modelData === "next") mediaNextProc.running = true // 下一首
                                    else mediaPlayProc.running = true // 播放/暂停切换
                                    mediaProc.running = true // 控制后立刻刷新元数据/状态（尽快同步 UI）
                                    mouse.accepted = true // 吃掉事件，避免外层误触
                                }
                            }
                        }
                    }
                }
            }
            Item { width: 1; height: unit * 0.3 } // 底部留白（让面板不显得太“顶”）
        }
    }
}
