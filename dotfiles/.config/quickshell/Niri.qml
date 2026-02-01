pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    property int activeIdx: 1
    property int workspaceCount: 5
    
    function updateWorkspaces(workspacesEvent) {
        const workspaceList = workspacesEvent.workspaces;
        workspaceList.sort((a, b) => a.idx - b.idx);
        workspaceCount = Math.max(workspaceList.length, 5);
        
        for (const ws of workspaceList) {
            if (ws.is_active) {
                activeIdx = ws.idx;
                break;
            }
        }
    }
    
    function activateWorkspace(event) {
        activeIdx = event.idx;
    }
    
    Process {
        id: niriEvents
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        
        stdout: SplitParser {
            onRead: data => {
                try {
                    const event = JSON.parse(data.trim());
                    if (event.WorkspacesChanged) {
                        updateWorkspaces(event.WorkspacesChanged);
                    }
                    else if (event.WorkspaceActivated) {
                        activateWorkspace(event.WorkspaceActivated);
                    }
                } catch (e) {
                    // ignore parse errors
                }
            }
        }
    }
    
    // 初始查询
    Component.onCompleted: {
        initQuery.running = true;
    }
    
    Process {
        id: initQuery
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const list = JSON.parse(data);
                    list.sort((a, b) => a.idx - b.idx);
                    workspaceCount = Math.max(list.length, 5);
                    for (const ws of list) {
                        if (ws.is_active) {
                            activeIdx = ws.idx;
                            break;
                        }
                    }
                } catch(e) {}
            }
        }
    }
}
