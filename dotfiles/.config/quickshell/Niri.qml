pragma Singleton

// 模块：Niri（Quickshell QML Singleton）
// 功能：为“工作区指示/切换”提供 niri 工作区状态（activeIdx/workspaceCount）的单例数据源。
// 关联功能：左侧工作区岛（LeftIsland）可以直接使用本单例（或直接调用 niri 命令，二者择一）。
// 数据来源：
// - 初始状态：`niri msg -j workspaces`（一次性拉取工作区列表与当前激活项）
// - 增量更新：`niri msg --json event-stream`（持续输出 JSON 事件流）
// 约束/注意：
// - stdout 可能包含半截 JSON（流式输出），因此解析必须 try/catch。
// - 本文件只维护“状态”，不直接发起 focus-workspace（由 UI 组件负责触发）。

import Quickshell // Quickshell 根类型（Singleton）等基础能力
import Quickshell.Io // Process/SplitParser：执行外部命令并解析输出
import QtQuick // QML 基础类型（Component、信号、属性）

Singleton {
    property int activeIdx: 1
    property int workspaceCount: 5
    
    function updateWorkspaces(workspacesEvent) {
        // 输入：workspacesEvent = event.WorkspacesChanged（来自 niri event-stream 的 JSON）
        // 输出：无返回值；通过副作用更新 activeIdx/workspaceCount
        // 副作用：写入本 Singleton 的属性（供 UI 绑定刷新）

        const workspaceList = workspacesEvent.workspaces; // 取出工作区数组（元素包含 id/idx/is_active 等）
        workspaceList.sort((a, b) => a.idx - b.idx); // 按 idx 升序排序，保证 UI 顺序稳定
        workspaceCount = Math.max(workspaceList.length, 5); // 兜底至少显示 5 个工作区指示（避免 UI 过短）
        
        for (const ws of workspaceList) { // 遍历排序后的工作区列表
            if (ws.is_active) { // 找到当前激活工作区
                activeIdx = ws.idx; // 同步激活工作区的 idx（用于 UI 高亮）
                break; // 找到后立刻退出循环（避免被后续覆盖）
            }
        }
    }
    
    function activateWorkspace(event) {
        // 输入：event = event.WorkspaceActivated（来自 niri event-stream 的 JSON）
        // 输出：无返回值；通过副作用更新 activeIdx
        // 注意：该事件可能携带 idx；若未来只携带 id，可改用映射转换（见 LeftIsland 的 idToIdxMap 思路）。

        activeIdx = event.idx; // 直接同步激活工作区 idx（用于 UI 高亮）
    }
    
    Process {
        id: niriEvents
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        
        stdout: SplitParser {
            onRead: data => {
                try {
                    const event = JSON.parse(data.trim()); // 尝试把当前分片解析为 JSON 事件对象
                    if (event.WorkspacesChanged) { // 工作区列表/状态发生变化
                        updateWorkspaces(event.WorkspacesChanged); // 更新列表长度与当前激活工作区
                    }
                    else if (event.WorkspaceActivated) { // 仅工作区激活项发生变化
                        activateWorkspace(event.WorkspaceActivated); // 更新激活工作区 idx
                    } // 其他事件忽略（本单例只关心工作区相关）
                } catch (e) {
                    // 忽略解析错误（常见原因：流式输出导致收到半截 JSON）
                }
            }
        }
    }
    
    // 初始查询
    Component.onCompleted: {
        initQuery.running = true; // 启动一次性查询：拉取当前工作区列表与激活项
    }
    
    Process {
        id: initQuery
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const list = JSON.parse(data); // 解析一次性查询输出：工作区数组
                    list.sort((a, b) => a.idx - b.idx); // 按 idx 升序排序，保证 UI 顺序稳定
                    workspaceCount = Math.max(list.length, 5); // 兜底至少显示 5 个工作区指示
                    for (const ws of list) { // 遍历以找到当前激活项
                        if (ws.is_active) { // niri 标记的激活工作区
                            activeIdx = ws.idx; // 同步激活 idx
                            break; // 找到后退出
                        }
                    } // 若未找到激活项，则保留默认值 activeIdx=1
                } catch(e) {}
            }
        }
    }
}
