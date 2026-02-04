// 模块：RightIslands（右侧岛屿组）
// 功能：顶栏右侧的组合组件，包含三块独立区域：
// 1) systemIsland：系统信息（cava 频谱 + MEM/CPU/BAT），点击后触发系统面板开关
// 2) trayIsland：系统托盘（SystemTray.items），支持左键激活与右键菜单
// 3) powerIsland：电源按钮（启动 wlogout）
// 数据来源：
// - cava 频谱：外部脚本输出 JSON（bars/active）
// - CPU/MEM/BAT：读取 /proc 与 /sys（定时刷新）
// 与外部交互：
// - signal toggleSystemPanel：点击 systemIsland 发出，由 Bar/shell 处理（切换系统面板窗口）
// - property panelWindow：用于托盘右键菜单锚点（QsMenuAnchor）定位到正确的窗口
// 注意：
// - CPU 使用率采用“差分采样”算法：使用上一次采样的 idle/total 来计算区间占用
// - 该组件会常驻启动 cavaProc（持续流式输出），并用 Timer 低频刷新 CPU/MEM/BAT

import QtQuick // QML 基础类型（Row/Rectangle/Text/Repeater 等）
import QtQuick.Layouts // 目前主要用于布局类型导入（便于未来扩展）
import Quickshell // 运行时基础（用于 QsMenuAnchor 的 anchor 等）
import Quickshell.Io // Process/SplitParser：读取系统文件/执行脚本
import Quickshell.Services.SystemTray // SystemTray.items：托盘数据源
import Quickshell.Widgets // QsMenuAnchor：托盘右键菜单锚点

Row {
    id: rightIslands
    property real unit: parent?.unit ?? 13.6 // 尺寸基准：优先继承父组件（Bar），否则使用默认值
    property color zenInk: parent?.zenInk ?? "#141414" // 背景色
    property color zenMist: parent?.zenMist ?? "#2a2a2a" // 边框/分割线色
    property color zenStone: parent?.zenStone ?? "#1f1f1f" // hover 背景色
    property color zenAsh: parent?.zenAsh ?? "#3a3a3a" // 弱对比色（分割线/托盘空态等）
    property color zenSmoke: parent?.zenSmoke ?? "#5a5a5a" // 弱文本色
    property color zenCloud: parent?.zenCloud ?? "#8a8a8a" // 中等文本色
    property color zenSnow: parent?.zenSnow ?? "#cacaca" // 高对比文本色
    property color zenAccent: "#5a9a8a" // 强调色（频谱条等；默认为固定值，也可由外部覆盖）
    property var panelWindow: null // 顶栏所在 PanelWindow；用于托盘菜单锚点定位（必填）

    // Cava 频谱数据
    property string cavaData: "▁▁▁▁▁▁▁▁" // 频谱柱字符序列（每个字符代表一个高度等级）
    property bool cavaActive: false // cava 是否处于“正在播放/有输入”的状态（由脚本决定）

    spacing: unit * 0.6 // 三个岛屿之间的间距
    height: parent?.height ?? unit * 2 // 高度优先继承父高度，否则按 unit 给出
    signal toggleSystemPanel() // 点击 systemIsland 时发出：请求切换系统面板（由外部处理）

    property int cpuPercent: 0 // CPU 使用率百分比（0-100）
    property int memPercent: 0 // 内存使用率百分比（0-100）
    property int _memTotal: 0 // MemTotal（kB；从 /proc/meminfo 读取）
    property int _memAvail: 0 // MemAvailable（kB；从 /proc/meminfo 读取）
    property int _prevCpuIdle: 0 // 上一次采样的 idleAll（用于差分计算）
    property int _prevCpuTotal: 0 // 上一次采样的 total（用于差分计算）
    property int batPercent: 100 // 电池电量百分比（0-100；无电池则回退 100）

    Component.onCompleted: {
        cpuProc.running = true // 启动时立刻采样一次 CPU
        memProc.running = true // 启动时立刻采样一次内存
        batProc.running = true // 启动时立刻采样一次电池
    }

    Timer {
        interval: 3000 // 3 秒刷新一次（权衡实时性与开销）
        running: true // 组件加载后立即开始
        repeat: true // 周期性触发
        onTriggered: {
            cpuProc.running = true // 触发 CPU 采样
            memProc.running = true // 触发内存采样
            batProc.running = true // 触发电池采样
        }
    }

    Process {
        id: cavaProc
        command: ["/home/shiyi/.config/eww/scripts/cava.sh"] // 外部脚本：输出 JSON（bars/active）
        running: true // 常驻运行：持续输出频谱数据
        stdout: SplitParser {
            onRead: data => {
                try {
                    let json = JSON.parse(data) // 解析脚本输出的 JSON
                    rightIslands.cavaData = json.bars || "▁▁▁▁▁▁▁▁" // bars 缺失时回退到低柱占位
                    rightIslands.cavaActive = json.active || false // active 缺失时回退 false
                } catch(e) {}
            }
        }
    }
    Process {
        id: cpuProc
        command: ["cat", "/proc/stat"] // 从内核统计读取 CPU 累计时间片（user/system/idle...）
        stdout: SplitParser { onRead: data => {
            if (data.startsWith("cpu ")) {
                let parts = data.split(/\s+/) // 拆分字段：["cpu", user, nice, system, idle, iowait, irq, softirq, ...]
                let user = parseInt(parts[1]) || 0 // user 时间（可运行态）
                let nice = parseInt(parts[2]) || 0 // nice 时间（低优先级 user）
                let system = parseInt(parts[3]) || 0 // system 时间（内核态）
                let idle = parseInt(parts[4]) || 0 // idle 时间（空闲）
                let iowait = parseInt(parts[5]) || 0 // iowait 时间（等待 IO 也算 idle 类）
                let irq = parseInt(parts[6]) || 0 // irq 时间（硬中断）
                let softirq = parseInt(parts[7]) || 0 // softirq 时间（软中断）
                let total = user + nice + system + idle + iowait + irq + softirq // 本次采样的累计总时间（简化版）
                let idleAll = idle + iowait // 合并 idle 类时间（用于利用率计算）
                let diffIdle = idleAll - rightIslands._prevCpuIdle // 距离上次采样的 idle 增量
                let diffTotal = total - rightIslands._prevCpuTotal // 距离上次采样的 total 增量
                rightIslands._prevCpuIdle = idleAll // 更新缓存：供下次差分计算
                rightIslands._prevCpuTotal = total // 更新缓存：供下次差分计算
                if (diffTotal > 0) {
                    rightIslands.cpuPercent = Math.round((1 - diffIdle / diffTotal) * 100) // 利用率 = 1 - idle/total
                }
            }
        }}
    }

    Process {
        id: memProc
        command: ["cat", "/proc/meminfo"] // 从内核读取内存信息（MemTotal/MemAvailable 等）
        stdout: SplitParser { onRead: data => {
            if (data.startsWith("MemTotal:")) {
                rightIslands._memTotal = parseInt(data.split(/\s+/)[1]) || 0 // 记录 MemTotal（kB）
            } else if (data.startsWith("MemAvailable:")) {
                rightIslands._memAvail = parseInt(data.split(/\s+/)[1]) || 0 // 记录 MemAvailable（kB）
                if (rightIslands._memTotal > 0) {
                    rightIslands.memPercent = Math.round((rightIslands._memTotal - rightIslands._memAvail) * 100 / rightIslands._memTotal) // 使用率 = (total-available)/total
                }
            }
        }}
    }

    Process {
        id: batProc
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100"] // 有电池则读 BAT0/capacity，否则回退 100
        stdout: SplitParser { onRead: data => rightIslands.batPercent = parseInt(data) || 100 } // 解析为整数百分比
    }

    Rectangle {
        id: systemIsland
        width: systemRow.implicitWidth + unit * 2 // 宽度 = 内容宽度 + 左右留白
        height: parent.height // 高度与顶栏一致
        color: zenInk // 背景色
        border.color: zenMist // 边框色
        border.width: 1 // 边框宽度
        radius: 2 // 圆角半径

        MouseArea {
            anchors.fill: parent // 点击热区覆盖整个系统岛
            hoverEnabled: true // 开启 hover（用于背景高亮）
            cursorShape: Qt.PointingHandCursor // 鼠标指针：提示可点击
            onEntered: systemIsland.color = zenStone // hover 时背景变亮
            onExited: systemIsland.color = zenInk // 离开 hover 时恢复背景色
            onClicked: {
                console.log("[RightIslands] systemIsland clicked") // 调试日志：记录点击（避免高频输出）
                rightIslands.toggleSystemPanel() // 上报“切换系统面板”意图（由外部处理）
            }
        }

        Row {
            id: systemRow
            anchors.centerIn: parent // 内容整体居中
            spacing: unit * 0.5 // 各段之间间距

            Row {
                spacing: 2 // 频谱柱之间的间距（像素）
                anchors.verticalCenter: parent.verticalCenter // 垂直居中对齐
                Repeater {
                    model: rightIslands.cavaData.length // 频谱柱数量由字符长度决定
                    Rectangle {
                        width: 2 // 单柱宽度（像素）
                        anchors.verticalCenter: parent.verticalCenter // 单柱垂直居中
                        height: unit * (0.1 + 0.7 * "▁▂▃▄▅▆▇█".indexOf(rightIslands.cavaData[index] || "▁") / 7) // 字符等级映射到 0~1 再映射到高度
                        color: zenAccent // 频谱柱颜色使用强调色
                        Behavior on height { NumberAnimation { duration: 80 } } // 高度变化做快速平滑（跟随音乐节奏）
                    }
                }
            }
            Rectangle { width: 1; height: unit * 0.7; color: zenMist; anchors.verticalCenter: parent.verticalCenter }

            Row {
                spacing: 4 // 标签与数值之间的间距
                anchors.verticalCenter: parent.verticalCenter // 垂直居中
                Text { text: "MEM"; font.pixelSize: unit * 0.32; color: zenCloud } // 内存标签
                Text { text: memPercent + "%"; font.pixelSize: unit * 0.38; color: zenSnow } // 内存百分比
            }

            Rectangle { width: 1; height: unit * 0.7; color: zenMist; anchors.verticalCenter: parent.verticalCenter }

            Row {
                spacing: 4 // 标签与数值之间的间距
                anchors.verticalCenter: parent.verticalCenter // 垂直居中
                Text { text: "CPU"; font.pixelSize: unit * 0.32; color: zenCloud } // CPU 标签
                Text { text: cpuPercent + "%"; font.pixelSize: unit * 0.38; color: zenSnow } // CPU 百分比
            }

            Rectangle { width: 1; height: unit * 0.7; color: zenMist; anchors.verticalCenter: parent.verticalCenter }

            Row {
                spacing: 4 // 电池图标与百分比之间的间距
                anchors.verticalCenter: parent.verticalCenter // 垂直居中
                Rectangle {
                    width: 16 // 电池外框宽度（像素）
                    height: 7 // 电池外框高度（像素）
                    color: "transparent" // 外框透明，只绘制边框
                    border.color: zenAsh // 外框边框颜色
                    border.width: 1 // 外框边框宽度
                    anchors.verticalCenter: parent.verticalCenter // 垂直居中
                    Rectangle {
                        x: 1 // 填充条内边距（左）
                        y: 1 // 填充条内边距（上）
                        width: Math.max((parent.width - 2) * batPercent / 100, 0) // 填充宽度按百分比缩放，且不为负
                        height: parent.height - 2 // 填充高度 = 外框高度 - 上下边距
                        color: zenCloud // 填充颜色（中等对比）
                    }
                }
                Text { text: batPercent + "%"; font.pixelSize: unit * 0.38; color: zenSnow } // 电量百分比文本
            }
        }
    }

    Rectangle {
        id: trayIsland
        width: Math.max(trayRow.implicitWidth + unit * 1.2, unit * 2.5) // 宽度至少能容纳托盘项；空态也保持最小宽度
        height: parent.height // 高度与顶栏一致
        color: zenInk // 背景色
        border.color: zenMist // 边框色
        border.width: 1 // 边框宽度
        radius: 2 // 圆角半径

        Row {
            id: trayRow
            anchors.centerIn: parent // 托盘项整体居中
            spacing: unit * 0.4 // 托盘项之间间距

            Repeater {
                model: SystemTray.items // Quickshell 系统托盘项列表（响应式）
                Item {
                    id: trayItemContainer
                    width: unit * 1.2 // 单个托盘项容器宽度
                    height: unit * 1.2 // 单个托盘项容器高度
                    Rectangle {
                        id: trayItemBg
                        anchors.fill: parent // 背景覆盖整个容器
                        color: "transparent" // 默认透明，仅在 hover 时变色
                        radius: 2 // 背景圆角
                        Image {
                            anchors.centerIn: parent // 图标居中
                            width: unit * 0.9 // 图标宽度
                            height: unit * 0.9 // 图标高度
                            source: modelData.icon // 托盘项图标（由 SystemTray 提供）
                            sourceSize.width: unit * 0.9 // 请求的源图尺寸（帮助选择合适分辨率）
                            sourceSize.height: unit * 0.9 // 请求的源图尺寸
                        }
                    }
                    MouseArea {
                        anchors.fill: parent // 点击热区覆盖整个托盘项
                        hoverEnabled: true // 开启 hover（用于背景高亮）
                        acceptedButtons: Qt.LeftButton | Qt.RightButton // 同时支持左键与右键
                        cursorShape: Qt.PointingHandCursor // 鼠标指针：提示可点击
                        onEntered: trayItemBg.color = zenStone // hover 时背景高亮
                        onExited: trayItemBg.color = "transparent" // 退出 hover 时恢复透明
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                if (modelData.hasMenu) menuAnchor.open() // 右键：若托盘项提供菜单则打开
                            } else {
                                modelData.activate() // 左键：执行托盘项默认激活行为（通常是打开窗口/切换状态）
                            }
                        }
                    }
                    QsMenuAnchor {
                        id: menuAnchor
                        menu: modelData.menu // 绑定托盘项提供的菜单对象
                        anchor.window: rightIslands.panelWindow // 菜单所属窗口（必须指定，否则可能无法定位/显示）
                        anchor.item: trayItemBg // 菜单锚点控件（菜单会贴近该 item 弹出）
                    }
                }
            }
            Text {
                visible: SystemTray.items.count === 0 // 空态：没有托盘项时显示占位符
                text: "···" // 占位符文本（不抢眼）
                font.pixelSize: unit * 0.4 // 占位符字号
                color: zenAsh // 占位符颜色（弱对比）
                anchors.verticalCenter: parent.verticalCenter // 垂直居中
            }
        }
    }

    Rectangle {
        id: powerIsland
        width: unit * 1.8 // 电源按钮岛宽度
        height: parent.height // 高度与顶栏一致
        color: zenInk // 背景色
        border.color: zenMist // 边框色
        border.width: 1 // 边框宽度
        radius: 2 // 圆角半径
        Text {
            anchors.centerIn: parent // 图标居中
            text: "⏻" // 电源符号（纯文本渲染）
            font.pixelSize: unit * 0.5 // 图标字号
            color: zenSmoke // 图标颜色（弱化，避免抢眼）
        }
        Process {
            id: wlogoutProc
            command: ["wlogout"] // 电源菜单程序（由系统提供）
        }
        MouseArea {
            anchors.fill: parent // 点击热区覆盖整个电源岛
            hoverEnabled: true // 开启 hover（用于背景/边框高亮）
            cursorShape: Qt.PointingHandCursor // 鼠标指针：提示可点击
            onEntered: { powerIsland.color = zenStone; powerIsland.border.color = zenSmoke } // hover 时背景变亮、边框变亮
            onExited: { powerIsland.color = zenInk; powerIsland.border.color = zenMist } // 退出 hover 时恢复
            onClicked: wlogoutProc.running = true // 点击时启动 wlogout（异步）
        }
    }
}
