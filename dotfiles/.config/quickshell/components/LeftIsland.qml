import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: leftIsland
    
    property real unit: parent?.unit ?? 13.6
    property color zenInk: parent?.zenInk ?? "#141414"
    property color zenMist: parent?.zenMist ?? "#2a2a2a"
    property color zenStone: parent?.zenStone ?? "#1f1f1f"
    property color zenCloud: parent?.zenCloud ?? "#8a8a8a"
    property color zenSnow: parent?.zenSnow ?? "#cacaca"
    
    implicitWidth: workspaceRow.implicitWidth + unit * 2.5
    implicitHeight: parent?.height ?? unit * 2
    
    color: zenInk
    border.color: zenMist
    border.width: 1
    radius: 2
    
    property int activeIdx: 1
    property int displayCount: 5
    property var idToIdxMap: ({})  // id -> idx 映射缓存
    
    Component.onCompleted: {
        initQuery.running = true
    }
    
    // 初始查询
    Process {
        id: initQuery
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    let list = JSON.parse(data)
                    list.sort((a, b) => a.idx - b.idx)
                    leftIsland.displayCount = list.length
                    
                    // 构建 id -> idx 映射
                    let newMap = {}
                    for (let ws of list) {
                        newMap[ws.id] = ws.idx
                        if (ws.is_active) {
                            leftIsland.activeIdx = ws.idx
                        }
                    }
                    leftIsland.idToIdxMap = newMap
                } catch(e) {}
            }
        }
    }
    
    // 事件流监听
    Process {
        id: niriEventStream
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        
        stdout: SplitParser {
            onRead: data => {
                try {
                    let event = JSON.parse(data.trim())
                    
                    if (event.WorkspacesChanged) {
                        // 工作区列表变化 - 重建映射
                        let list = event.WorkspacesChanged.workspaces
                        list.sort((a, b) => a.idx - b.idx)
                        leftIsland.displayCount = list.length
                        
                        let newMap = {}
                        for (let ws of list) {
                            newMap[ws.id] = ws.idx
                            if (ws.is_active) {
                                leftIsland.activeIdx = ws.idx
                            }
                        }
                        leftIsland.idToIdxMap = newMap
                    }
                    else if (event.WorkspaceActivated) {
                        // 工作区切换 - 用缓存的映射转换 id -> idx
                        let wsId = event.WorkspaceActivated.id
                        let wsIdx = leftIsland.idToIdxMap[wsId]
                        if (wsIdx !== undefined) {
                            leftIsland.activeIdx = wsIdx
                        }
                    }
                } catch(e) {}
            }
        }
    }
    
    RowLayout {
        id: workspaceRow
        anchors.centerIn: parent
        spacing: unit * 0.35
        
        Repeater {
            model: leftIsland.displayCount
            
            Rectangle {
                id: wsBtn
                
                property bool isActive: (index + 1) === leftIsland.activeIdx
                property int wsIndex: index + 1
                
                Layout.preferredWidth: isActive ? unit * 1.6 : unit * 0.45
                Layout.preferredHeight: unit * 0.45
                
                color: isActive ? zenSnow : zenMist
                radius: 1
                
                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                }
                
                Behavior on color {
                    ColorAnimation { duration: 200 }
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        clickProcess.command = ["niri", "msg", "action", "focus-workspace", String(wsBtn.wsIndex)]
                        clickProcess.running = true
                    }
                }
            }
        }
    }
    
    Process {
        id: clickProcess
        command: ["echo"]
    }
    
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        onEntered: leftIsland.color = zenStone
        onExited: leftIsland.color = zenInk
        onPressed: mouse => mouse.accepted = false
        onReleased: mouse => mouse.accepted = false
    }
}
