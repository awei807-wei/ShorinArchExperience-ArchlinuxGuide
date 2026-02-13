// 模块：CenterIsland（中岛）
// 功能：顶栏中间区域的“单一岛屿”组件：
// - 默认显示时间/日期（本地时间）
// - 当 shell 侧检测到音量变化时，切换为“音量反馈 UI”（showVolume=true）并显示音量百分比
// - 当收到“音量到顶”提示时，通过 shake() 触发抖动动画加强提示
// 与外部交互：
// - signal togglePanel：用户点击中岛时发出，由 Bar 转发给 shell 来切换中心面板窗口
// - property showVolume/volume：由 shell 注入/修改，驱动“时间布局”与“音量布局”互斥显示
// 注意：
// - 本组件自身不会读取系统音量；它只负责“展示”，数据采集在 shell 中完成

import QtQuick // QML 基础类型（Rectangle/Text/Timer/Animation 等）
import QtQuick.Layouts // 目前主要用于布局类型导入（便于未来扩展）
import Quickshell // 运行时基础（此文件未直接依赖，但保持一致的导入习惯）
import Quickshell.Io // 运行时 IO（此文件未直接依赖；若未来增加读取可复用）

Rectangle {
    id: centerIsland
    property real unit: parent?.unit ?? 13.6 // 尺寸基准：优先继承父组件（Bar），否则使用默认值
    property color zenInk: parent?.zenInk ?? "#141414" // 背景色（默认回退值）
    property color zenMist: parent?.zenMist ?? "#2a2a2a" // 边框/分割线色（默认回退值）
    property color zenStone: parent?.zenStone ?? "#1f1f1f" // hover 背景色（默认回退值）
    property color zenAsh: parent?.zenAsh ?? "#3a3a3a" // 弱对比色（默认回退值）
    property color zenSmoke: parent?.zenSmoke ?? "#5a5a5a" // 文本/图标弱色（默认回退值）
    property color zenCloud: parent?.zenCloud ?? "#8a8a8a" // 文本中等对比色（默认回退值）
    property color zenSnow: parent?.zenSnow ?? "#cacaca" // 文本高对比色（默认回退值）
    property color zenAccent: parent?.zenAccent ?? "#5a9a8a" // 强调色（音量条填充色等）
    property string weatherStr: "... °C" // 存储天气脚本输出

    implicitWidth: unit * 12 // 增加宽度以容纳天气
    implicitHeight: parent?.height ?? unit * 2 // 默认高度：优先继承父高度，否则按 unit 给出
    color: zenInk // 背景填充色
    border.color: zenMist // 边框颜色
    border.width: 1 // 边框宽度（像素）
    radius: 2 // 圆角半径（像素；与 unit 无关，保持“硬朗”风格）

    property string timeStr: "00:00" // 时间字符串（Timer 每秒刷新）
    property string dateStr: "2026.01.30" // 日期字符串
    property string weekdayStr: "" // 周几字符串
    
    // 动态切换属性
    property bool showVolume: false // true=展示音量反馈布局；false=展示时间布局
    property real shakeOffset: 0 // 抖动动画的水平偏移量（通过 Translate 应用）
    property int volume: 0 // 当前音量百分比（0-100；由 shell 写入）

    signal togglePanel()

    // 抖动动画
    function shake() {
        // 输入：无
        // 输出：无返回值
        // 副作用：启动 shakeAnim，驱动 shakeOffset 变化，从而触发视觉抖动
        // 触发来源：通常由 shell 在“音量到顶提示”等场景调用

        shakeAnim.start() // 启动动画序列（会自动按 loops 执行）
    }

    SequentialAnimation {
        id: shakeAnim
        loops: 2
        NumberAnimation { target: centerIsland; property: "shakeOffset"; to: 4; duration: 45; easing.type: Easing.OutQuad }
        NumberAnimation { target: centerIsland; property: "shakeOffset"; to: -4; duration: 45; easing.type: Easing.OutQuad }
        NumberAnimation { target: centerIsland; property: "shakeOffset"; to: 0; duration: 45; easing.type: Easing.OutQuad }
    }

    Timer {
        interval: 1000 // 每 1 秒刷新一次时间/日期字符串
        running: true // 组件创建后即开始计时
        repeat: true // 周期性触发
        triggeredOnStart: true // 创建后立即触发一次，避免首秒显示默认占位
        onTriggered: {
            let now = new Date()
            centerIsland.timeStr = now.toTimeString().slice(0, 5)
            let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
            centerIsland.weekdayStr = weekdays[now.getDay()]
            centerIsland.dateStr = now.getFullYear() + "." +
                String(now.getMonth() + 1).padStart(2, "0") + "." +
                String(now.getDate()).padStart(2, "0")
        }
    }

    // 天气获取进程
    Process {
        id: weatherProc
        command: ["python", "/home/shiyi/.config/waybar/scripts/weather.py"]
        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim()
                // 防御性编程：确保只处理 JSON 行，过滤掉警告或空行
                if (trimmed.startsWith("{") && trimmed.endsWith("}")) {
                    try {
                        let obj = JSON.parse(trimmed)
                        if (obj.text) {
                            centerIsland.weatherStr = obj.text
                        }
                    } catch(e) {
                        // 解析失败时不更新 UI，保持上一次的有效值，避免闪烁
                        console.log("Weather parse error: " + e)
                    }
                }
            }
        }
    }

    // 天气刷新定时器（每 15 分钟）
    Timer {
        interval: 900000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherProc.running = true
    }

    // 时间与天气分栏布局 - 网页级嵌套弹性盒子重构 (Nested Centering)
    RowLayout {
        anchors.fill: parent
        spacing: 0
        visible: !centerIsland.showVolume

        // 左子容器 (父 Div 1)
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            // 嵌套弹性盒子重构：左子 Div(时间/日期) + 右子 Div(周几)
            RowLayout {
                anchors.centerIn: parent
                spacing: 0

                // 左子 Div (时间/日期)
                Item {
                    Layout.preferredWidth: unit * 3.8
                    Layout.fillHeight: true
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        spacing: -unit * 0.1 // 稍微压缩行距，增加紧凑感
                        Text {
                            text: centerIsland.timeStr
                            font.pixelSize: unit * 0.58 // 稍微放大 L1
                            font.family: "JetBrains Mono"
                            font.bold: true
                            color: zenSnow
                        }
                        Text {
                            text: centerIsland.dateStr
                            font.pixelSize: unit * 0.22 // 缩小 L3
                            font.family: "JetBrains Mono"
                            color: zenSmoke
                            anchors.right: parent.right
                        }
                    }
                }

                // 间距占位
                Item { Layout.preferredWidth: unit * 0.4 }

                // 右子 Div (周几) - 视觉中心对齐修正
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Text {
                        text: centerIsland.weekdayStr
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -unit * 0.02 // 极微调：对齐 L1 视觉重心
                        anchors.left: parent.left
                        font.pixelSize: unit * 0.36 // 稍微放大 L2，增加可读性
                        font.family: "JetBrains Mono"
                        color: zenCloud
                    }
                }
            }
        }

        // 中间分隔线 (不参与弹性占位，固定居中)
        Rectangle {
            width: 1
            height: unit * 1.1
            color: zenMist
            Layout.alignment: Qt.AlignVCenter
        }

        // 右子容器 (Div 2)
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Text {
                anchors.centerIn: parent // 子容器内绝对居中
                text: centerIsland.weatherStr
                font.pixelSize: unit * 0.48
                font.family: "JetBrains Mono"
                color: zenCloud
            }
        }
    }

    // 音量反馈布局
    Column {
        transform: Translate { x: centerIsland.shakeOffset } // 将抖动偏移应用到整个音量布局（实现左右抖动）
        anchors.centerIn: parent // 音量布局整体居中
        width: parent.width * 0.8 // 音量条相对父宽度缩窄，保留两侧留白
        spacing: unit * 0.2 // “标题行”与“进度条”之间的间距
        visible: centerIsland.showVolume // 当显示音量反馈时才显示该布局
        
        Row {
            anchors.horizontalCenter: parent.horizontalCenter // 标题行水平居中
            spacing: unit * 0.4 // “VOL” 与 “xx%” 之间的间距
            Text { 
                text: "VOL" // 固定标签：表示当前展示的是音量
                font.pixelSize: unit * 0.35 // 标签字号
                font.family: "JetBrains Mono" // 等宽字体
                color: zenCloud // 中等对比色
            }
            Text { 
                text: centerIsland.volume + "%" // 当前音量百分比（由 shell 写入）
                font.pixelSize: unit * 0.35 // 数值字号（与标签一致）
                font.family: "JetBrains Mono" // 等宽字体
                color: zenSnow // 高对比色（突出数值）
                font.bold: true // 加粗（进一步突出）
            }
        }
        
        Rectangle {
            width: parent.width // 进度条背景宽度占满音量布局
            height: 3 // 进度条高度（像素）
            color: zenMist // 进度条背景色
            Rectangle {
                width: parent.width * Math.min(centerIsland.volume / 100, 1.0) // 填充比例：volume/100，最大不超过 1
                height: parent.height // 填充高度与背景一致
                color: zenAccent // 填充颜色使用强调色
            }
        }
    }

    MouseArea {
        anchors.fill: parent // 点击热区覆盖整个岛屿
        hoverEnabled: true // 开启 hover 事件（用于高亮）
        cursorShape: Qt.PointingHandCursor // 鼠标指针：提示可点击
        onEntered: centerIsland.color = zenStone // hover 时切换背景色（视觉反馈）
        onExited: centerIsland.color = zenInk // 离开 hover 时恢复背景色
        onClicked: centerIsland.togglePanel() // 点击时上报“切换中心面板”意图（由外部处理）
    }
}
