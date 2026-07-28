pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: niriState

    readonly property bool testMode: {
        const value = env("QUICKSHELL_TEST_MODE").toLowerCase()
        return value === "1" || value === "true" || value === "yes"
    }
    readonly property bool enabled: {
        const desktop = (env("XDG_CURRENT_DESKTOP") + " "
            + env("XDG_SESSION_DESKTOP")).toLowerCase()
        return !testMode && (env("NIRI_SOCKET") !== "" || desktop.indexOf("niri") !== -1)
    }
    property var workspaces: []
    property bool ready: false
    property string errorMessage: ""
    property bool parseErrorLogged: false
    property int reconnectAttempts: 0
    property int pendingWorkspace: 0
    property string pendingOutput: ""

    readonly property string focusedOutput: {
        for (let index = 0; index < workspaces.length; index += 1) {
            const workspace = workspaces[index]
            if (workspace.is_focused)
                return workspace.output || ""
        }
        return ""
    }

    function env(name) {
        const value = Quickshell.env(name)
        return value === null || value === undefined ? "" : String(value)
    }

    function normalizeWorkspace(workspace) {
        return {
            "id": Number(workspace.id) || 0,
            "idx": Number(workspace.idx) || 1,
            "name": workspace.name || "",
            "output": workspace.output || "",
            "is_active": workspace.is_active === true,
            "is_focused": workspace.is_focused === true,
            "is_urgent": workspace.is_urgent === true,
            "active_window_id": workspace.active_window_id || null
        }
    }

    function applyWorkspaces(workspaceList) {
        if (!Array.isArray(workspaceList)) {
            errorMessage = "INVALID WORKSPACE DATA"
            return
        }

        const normalized = workspaceList.map(normalizeWorkspace)
        normalized.sort((left, right) => {
            if (left.output === right.output)
                return left.idx - right.idx
            return left.output.localeCompare(right.output)
        })
        workspaces = normalized
        ready = true
        errorMessage = ""
        reconnectAttempts = 0
    }

    function workspaceForOutput(outputName) {
        let focusedWorkspace = null
        let firstActiveWorkspace = null

        for (let index = 0; index < workspaces.length; index += 1) {
            const workspace = workspaces[index]
            if (workspace.is_focused)
                focusedWorkspace = workspace
            if (workspace.is_active && firstActiveWorkspace === null)
                firstActiveWorkspace = workspace
            if (outputName !== "" && workspace.output === outputName && workspace.is_active)
                return workspace
        }

        return focusedWorkspace || firstActiveWorkspace
    }

    function occupiedIndexes(outputName) {
        const indexes = []
        for (let index = 0; index < workspaces.length; index += 1) {
            const workspace = workspaces[index]
            if (outputName !== "" && workspace.output !== outputName)
                continue
            if (workspace.active_window_id !== null && indexes.indexOf(workspace.idx) === -1)
                indexes.push(workspace.idx)
        }
        return indexes
    }

    function refresh() {
        if (enabled && !initialQuery.running)
            initialQuery.running = true
    }

    function handleEvent(event) {
        if (event.WorkspacesChanged) {
            applyWorkspaces(event.WorkspacesChanged.workspaces)
            return
        }

        if (event.WorkspaceActivated || event.WindowFocusChanged)
            refreshDebounce.restart()
    }

    function startEventStream() {
        if (enabled && !eventStream.running)
            eventStream.running = true
    }

    function focusWorkspace(workspaceIndex, outputName) {
        if (!enabled || workspaceIndex < 1)
            return

        pendingWorkspace = workspaceIndex
        pendingOutput = outputName || ""

        if (pendingOutput !== "" && pendingOutput !== focusedOutput) {
            if (!focusMonitorProcess.running) {
                focusMonitorProcess.command = ["niri", "msg", "action", "focus-monitor", pendingOutput]
                focusMonitorProcess.running = true
            }
            return
        }

        runPendingWorkspaceFocus()
    }

    function runPendingWorkspaceFocus() {
        if (focusWorkspaceProcess.running || pendingWorkspace < 1)
            return

        const workspaceIndex = pendingWorkspace
        pendingWorkspace = 0
        focusWorkspaceProcess.command = [
            "niri", "msg", "action", "focus-workspace", String(workspaceIndex)
        ]
        focusWorkspaceProcess.running = true
    }

    Component.onCompleted: {
        if (enabled) {
            refresh()
            startEventStream()
        }
    }

    Process {
        id: initialQuery
        command: ["niri", "msg", "-j", "workspaces"]
        onExited: {
            if (!niriState.ready && niriState.errorMessage === "")
                niriState.errorMessage = "NIRI OFFLINE"
        }
        stdout: SplitParser {
            onRead: data => {
                try {
                    niriState.applyWorkspaces(JSON.parse(data))
                } catch (error) {
                    niriState.errorMessage = "NIRI DATA ERROR"
                    if (!niriState.parseErrorLogged) {
                        niriState.parseErrorLogged = true
                        console.warn("[Niri] invalid workspace payload: " + error)
                    }
                }
            }
        }
    }

    Process {
        id: eventStream
        command: ["niri", "msg", "--json", "event-stream"]
        onExited: {
            if (!niriState.enabled)
                return
            niriState.errorMessage = "NIRI RECONNECTING"
            niriState.reconnectAttempts += 1
            reconnectTimer.restart()
        }
        stdout: SplitParser {
            onRead: data => {
                try {
                    niriState.handleEvent(JSON.parse(data.trim()))
                } catch (error) {
                    if (!niriState.parseErrorLogged) {
                        niriState.parseErrorLogged = true
                        console.warn("[Niri] invalid event payload: " + error)
                    }
                }
            }
        }
    }

    Timer {
        id: reconnectTimer
        interval: Math.min(10000, 1000 * Math.pow(2, Math.min(niriState.reconnectAttempts, 3)))
        repeat: false
        onTriggered: {
            niriState.refresh()
            niriState.startEventStream()
        }
    }

    Timer {
        id: refreshDebounce
        interval: 45
        repeat: false
        onTriggered: niriState.refresh()
    }

    Process {
        id: focusMonitorProcess
        command: ["niri", "msg", "action", "focus-monitor", ""]
        onExited: niriState.runPendingWorkspaceFocus()
    }

    Process {
        id: focusWorkspaceProcess
        command: ["niri", "msg", "action", "focus-workspace", "1"]
        onExited: {
            if (niriState.pendingWorkspace > 0)
                niriState.runPendingWorkspaceFocus()
        }
    }
}
