// 模块：SystemPanel（系统弹出面板）
// 功能：展示系统状态的摘要信息（CPU/内存/电池），用于“快速查看”。
// 说明：
// - 这是一个“面板内容组件”，通常应由 shell.qml 的 PanelWindow 作为容器承载。
// - 当前仓库的 shell.qml 可能使用内联 UI（直接在 shell.qml 写系统面板内容），
//   因此该组件可能暂未被引用；但保留它有利于未来组件化/复用。
// 数据来源（通过外部命令采集）：
// - CPU：从 /proc/stat 计算 user+system 占比（简化算法）
// - 内存：`free -g` 读取已用内存（以 GB 为单位，展示为进度条）
// - 电池：读取 /sys/class/power_supply/BAT0/capacity（无电池回退 100）
// 注意：
// - 内存总量在此文件中写死为 32GB（见进度条宽度计算），属于展示假设；
//   如需自适应，应像 RightIslands 一样读取 MemTotal。

import QtQuick // QML 基础类型（Item/Rectangle/Text/MouseArea 等）
import QtQuick.Layouts // 目前主要用于布局类型导入（便于未来扩展）
import Quickshell // 运行时基础
import Quickshell.Io // Process/SplitParser：执行外部命令并解析输出

Item {
    id: systemRoot
    property real unit: 24 // 尺寸基准（由外部注入；用于统一缩放）
    property color zenInk: "#141414" // 背景色
    property color zenMist: "#2a2a2a" // 边框/分割线色
    property color zenStone: "#1f1f1f" // hover 背景色（本组件主要用于拦截层，较少用）
    property color zenAsh: "#3a3a3a" // 弱对比色（分区标题）
    property color zenSmoke: "#5a5a5a" // 弱文本色（标签）
    property color zenCloud: "#8a8a8a" // 中等文本色（数值）
    property color zenSnow: "#cacaca" // 高对比文本色（主要信息）
    property color zenAccent: "#5a9a8a" // 强调色（CPU/电池进度条填充色）

    property int cpuPercent: 0 // CPU 使用率百分比（0-100）
    property real memUsed: 0 // 已用内存（GB；由 free -g 读取并解析）
    property int batPercent: 100 // 电池电量百分比（0-100；无电池回退 100）

    implicitWidth: unit * 18 // 面板默认宽度（供外部布局计算）
    implicitHeight: sysContent.height + unit * 1.0 // 面板默认高度 = 内容高度 + 上下留白

    function refreshData() {
        // 输入：无
        // 输出：无返回值
        // 副作用：启动各个 Process 刷新系统状态数据
        // 触发来源：Component.onCompleted 自动触发；也可由外部在面板展开时按需调用

        cpuProc.running = true // 刷新 CPU 百分比
        memProc.running = true // 刷新已用内存
        batProc.running = true // 刷新电池百分比
    }

    Component.onCompleted: refreshData() // 组件加载完成后立刻刷新一次，避免显示占位值

    Process { id: cpuProc; command: ["sh", "-c", "grep 'cpu ' /proc/stat | awk '{u=($2+$4)*100/($2+$4+$5)} END {printf \"%.0f\", u}'"]; stdout: SplitParser { onRead: data => systemRoot.cpuPercent = parseInt(data) || 0 } } // CPU：简化算法（user+system）/（user+system+idle）
    Process { id: memProc; command: ["sh", "-c", "free -g | awk '/Mem:/ {printf \"%.1f\", $3}'"]; stdout: SplitParser { onRead: data => systemRoot.memUsed = parseFloat(data) || 0 } } // 内存：读取已用 GB（浮点）
    Process { id: batProc; command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100"]; stdout: SplitParser { onRead: data => systemRoot.batPercent = parseInt(data) || 100 } } // 电池：读 BAT0/capacity，无电池回退 100

    Rectangle {
        id: sysBg
        anchors.fill: parent // 背景覆盖整个组件
        color: zenInk; border.color: zenMist; border.width: 1; radius: 2 // 背景色 + 边框 + 圆角

        MouseArea {
            anchors.fill: parent // 拦截层覆盖整个面板
            propagateComposedEvents: false // 不让事件穿透到下层（避免点击触发“关闭面板”的外层逻辑）
            onClicked: mouse => mouse.accepted = true // 明确吃掉点击事件
        }

        Column {
            id: sysContent
            anchors.top: parent.top; anchors.topMargin: unit * 0.5 // 顶部留白
            anchors.left: parent.left; anchors.right: parent.right // 左右填充
            spacing: unit * 0.5 // 分区间距

            Text { x: unit * 0.8; text: "SYSTEM STATUS"; font.pixelSize: unit * 0.28; font.letterSpacing: 3; color: zenAsh } // 分区标题

            Column {
                x: unit * 0.8; spacing: unit * 0.2 // CPU 分区：左对齐并保持紧凑间距
                Text { text: "CPU LOAD"; font.pixelSize: unit * 0.35; color: zenSmoke } // 标签
                Rectangle {
                    width: unit * 16.4; height: 4; color: zenMist // 进度条背景
                    Rectangle { width: parent.width * systemRoot.cpuPercent / 100; height: 4; color: zenAccent } // 进度条填充
                }
                Text { text: systemRoot.cpuPercent + "% / 16 Cores"; font.pixelSize: unit * 0.3; color: zenCloud } // 数值说明（核心数为示例/固定文案）
            }

            Column {
                x: unit * 0.8; spacing: unit * 0.2 // 内存分区
                Text { text: "MEMORY USAGE"; font.pixelSize: unit * 0.35; color: zenSmoke } // 标签
                Rectangle {
                    width: unit * 16.4; height: 4; color: zenMist // 进度条背景
                    Rectangle { width: parent.width * (systemRoot.memUsed / 32); height: 4; color: zenCloud } // 填充条：假设总内存 32GB
                }
                Text { text: systemRoot.memUsed + "GB / 32GB Total"; font.pixelSize: unit * 0.3; color: zenCloud } // 数值说明（总内存为固定文案）
            }

            Column {
                x: unit * 0.8; spacing: unit * 0.2 // 电源分区
                Text { text: "POWER RESOURCE"; font.pixelSize: unit * 0.35; color: zenSmoke } // 标签
                Row {
                    spacing: unit * 0.4 // 电池图形与文本间距
                    Rectangle {
                        width: unit * 2; height: unit * 0.8; color: "transparent"; border.color: zenAsh; border.width: 1 // 电池外框
                        Rectangle { x: 1; y: 1; width: (parent.width-2) * systemRoot.batPercent / 100; height: parent.height-2; color: zenAccent } // 电池填充条
                    }
                    Text { text: systemRoot.batPercent + "% Healthy"; font.pixelSize: unit * 0.35; color: zenCloud } // 电量文本（Healthy 为固定文案）
                }
            }
            Item { width: 1; height: unit * 0.2 } // 底部留白
        }
    }
}
