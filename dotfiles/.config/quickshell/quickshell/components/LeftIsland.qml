// 模块：LeftIsland（左岛）
// 功能：顶栏左侧的“工作区指示/切换”组件（面向 niri 窗口管理器）。
// 行为概览：
// - 启动时执行一次 `niri msg -j workspaces` 获取初始工作区列表与当前激活项
// - 常驻 `niri msg --json event-stream` 监听后续变更（WorkspacesChanged/WorkspaceActivated）
// - 将工作区渲染为一排小矩形“指示点”；当前激活工作区会更宽以突出显示
// - 点击某个指示点会执行 `niri msg action focus-workspace <idx>` 切换工作区
// 关键实现点：
// - niri 的激活事件可能给 id 而不是 idx，因此维护 idToIdxMap 进行转换，保证 UI 高亮正确
// - 该组件是“自包含”的：它不依赖 Niri.qml 单例（两者功能重叠，可按需要统一）

import QtQuick // QML 基础类型（Rectangle/MouseArea/Repeater 等）
import QtQuick.Layouts // RowLayout / Layout.*：用于居中与间距控制
import Quickshell // 运行时基础类型（保持一致的导入习惯）
import Quickshell.Io // Process/SplitParser：执行 niri 命令并解析输出

Rectangle {
    id: leftIsland
    
    property real unit: parent?.unit ?? 13.6 // 尺寸基准：优先继承父组件（Bar），否则使用默认值
    property color zenInk: parent?.zenInk ?? "#141414" // 背景色
    property color zenMist: parent?.zenMist ?? "#2a2a2a" // 边框色/非激活色
    property color zenStone: parent?.zenStone ?? "#1f1f1f" // hover 背景色
    property color zenCloud: parent?.zenCloud ?? "#8a8a8a" // 文本中等对比色（此组件很少用到文本）
    property color zenSnow: parent?.zenSnow ?? "#cacaca" // 高对比色（激活指示点用）
    
    implicitWidth: workspaceRow.implicitWidth + unit * 2.5 // 宽度 = 指示点宽度之和 + 左右留白
    implicitHeight: parent?.height ?? unit * 2 // 高度优先继承父高度，否则按 unit 给出

    color: zenInk // 岛屿背景色
    border.color: zenMist // 岛屿边框色
    border.width: 1 // 边框宽度
    radius: 2 // 圆角半径

    property int activeIdx: 1 // 当前激活工作区 idx（用于 UI 高亮）
    property int displayCount: 5 // 当前显示的工作区数量（用于 Repeater model）
    property var idToIdxMap: ({})  // 工作区 id -> idx 映射缓存（用于 WorkspaceActivated 事件转换）
    
    Component.onCompleted: {
        initQuery.running = true // 组件加载完成后立刻拉取一次初始工作区状态
    }
    
    // 初始查询
    Process {
        id: initQuery
        command: ["niri", "msg", "-j", "workspaces"] // 一次性输出 JSON 数组：当前所有工作区
        stdout: SplitParser {
            onRead: data => {
                try {
                    let list = JSON.parse(data) // 解析工作区数组（包含 id/idx/is_active 等）
                    list.sort((a, b) => a.idx - b.idx) // 按 idx 升序排序，保证 UI 顺序稳定
                    leftIsland.displayCount = list.length // 将显示数量同步为实际工作区数量
                    
                    // 构建 id -> idx 映射
                    let newMap = {} // 新映射对象（先构建完再整体替换，避免中途不一致）
                    for (let ws of list) { // 遍历工作区列表构建映射与激活项
                        newMap[ws.id] = ws.idx // 记录 id -> idx（用于后续激活事件）
                        if (ws.is_active) { // 找到当前激活工作区
                            leftIsland.activeIdx = ws.idx // 同步激活 idx（用于 UI 高亮）
                        }
                    }
                    leftIsland.idToIdxMap = newMap // 原子替换映射（避免部分更新）
                } catch(e) {}
            }
        }
    }
    
    // 事件流监听
    Process {
        id: niriEventStream
        running: true // 常驻运行：持续监听 niri 事件流
        command: ["niri", "msg", "--json", "event-stream"] // 输出 JSON 事件对象（逐条输出）
        
        stdout: SplitParser {
            onRead: data => {
                try {
                    let event = JSON.parse(data.trim()) // 解析当前事件分片（可能是 WorkspacesChanged/WorkspaceActivated 等）
                    
                    if (event.WorkspacesChanged) {
                        // 工作区列表变化 - 重建映射
                        let list = event.WorkspacesChanged.workspaces // 取出新的工作区数组
                        list.sort((a, b) => a.idx - b.idx) // 按 idx 升序排序，保证 UI 顺序稳定
                        leftIsland.displayCount = list.length // 同步工作区数量（驱动 Repeater）
                        
                        let newMap = {} // 重建 id->idx 映射（WorkspacesChanged 可能改变 id/idx 分配）
                        for (let ws of list) { // 遍历构建映射与激活项
                            newMap[ws.id] = ws.idx // 更新映射
                            if (ws.is_active) { // 找到激活工作区
                                leftIsland.activeIdx = ws.idx // 同步激活 idx
                            }
                        }
                        leftIsland.idToIdxMap = newMap // 原子替换映射
                    }
                    else if (event.WorkspaceActivated) {
                        // 工作区切换 - 用缓存的映射转换 id -> idx
                        let wsId = event.WorkspaceActivated.id // niri 事件携带的工作区 id（稳定标识）
                        let wsIdx = leftIsland.idToIdxMap[wsId] // 用缓存映射把 id 转为 idx（用于 UI 顺序/高亮）
                        if (wsIdx !== undefined) { // 映射存在才更新（避免旧事件/未知 id 导致错误）
                            leftIsland.activeIdx = wsIdx // 更新激活 idx（驱动 UI 高亮）
                        } // 若映射缺失，通常意味着映射未就绪或工作区列表刚变化；等待下一次 WorkspacesChanged 修正
                    }
                } catch(e) {}
            }
        }
    }
    
    RowLayout {
        id: workspaceRow
        anchors.centerIn: parent // 指示点整体居中（保持岛屿两侧留白一致）
        spacing: unit * 0.35 // 指示点之间的间距
        
        Repeater {
            model: leftIsland.displayCount // 渲染 displayCount 个工作区指示点
            
            Rectangle {
                id: wsBtn
                
                property bool isActive: (index + 1) === leftIsland.activeIdx // 当前指示点是否对应激活工作区
                property int wsIndex: index + 1 // niri focus-workspace 使用 1-based idx
                
                Layout.preferredWidth: isActive ? unit * 1.6 : unit * 0.45 // 激活项更宽（视觉强调）
                Layout.preferredHeight: unit * 0.45 // 指示点高度
                
                color: isActive ? zenSnow : zenMist // 激活项用高对比色，非激活用弱色
                radius: 1 // 指示点圆角（轻微）
                
                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: 280; easing.type: Easing.OutCubic } // 宽度变化做平滑过渡（切换工作区时更“顺滑”）
                }
                
                Behavior on color {
                    ColorAnimation { duration: 200 } // 颜色变化做平滑过渡（高亮切换）
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor // 鼠标指针：提示可点击
                    onClicked: {
                        clickProcess.command = ["niri", "msg", "action", "focus-workspace", String(wsBtn.wsIndex)] // 组装切换工作区命令
                        clickProcess.running = true // 启动命令执行（异步）
                    }
                }
            }
        }
    }
    
    Process {
        id: clickProcess
        command: ["echo"] // 占位命令：实际点击时会被替换为 niri focus-workspace
    }
    
    MouseArea {
        anchors.fill: parent // hover 热区覆盖整个岛屿
        hoverEnabled: true // 开启 hover 事件（用于背景高亮）
        propagateComposedEvents: true // 允许事件继续传播（避免影响 Bar 的全局点击逻辑）
        onEntered: leftIsland.color = zenStone // hover 时切换背景色（视觉反馈）
        onExited: leftIsland.color = zenInk // 离开 hover 时恢复背景色
        onPressed: mouse => mouse.accepted = false // 不吞掉按下事件（避免阻断其他层的交互）
        onReleased: mouse => mouse.accepted = false // 不吞掉释放事件（与 onPressed 保持一致）
    }
}
