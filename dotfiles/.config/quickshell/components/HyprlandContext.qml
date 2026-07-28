import QtQuick
import Quickshell.Hyprland

ContextContent {
    id: hyprlandContext

    readonly property var monitor: targetScreen
        ? Hyprland.monitorFor(targetScreen) : Hyprland.focusedMonitor
    readonly property int activeWorkspace: monitor && monitor.activeWorkspace
        ? monitor.activeWorkspace.id
        : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)
    readonly property int rangeStart: activeWorkspace <= 3 ? 1 : activeWorkspace - 2
    readonly property var workspaceValues: Hyprland.workspaces.values
    readonly property var occupiedWorkspaces: collectOccupiedWorkspaces()

    function collectOccupiedWorkspaces() {
        const occupied = []
        const values = workspaceValues || []
        for (let index = 0; index < values.length; index += 1) {
            const workspace = values[index]
            if (!workspace || workspace.id < 1)
                continue
            if (monitor && workspace.monitor && workspace.monitor.name !== monitor.name)
                continue

            const toplevels = workspace.toplevels && workspace.toplevels.values
                ? workspace.toplevels.values : []
            if (toplevels.length > 0)
                occupied.push(workspace.id)
        }
        return occupied
    }

    function pad2(value) {
        return String(value).padStart(2, "0")
    }

    function focusWorkspace(workspace) {
        if (monitor && !monitor.focused)
            Hyprland.dispatch("focusmonitor " + monitor.name)
        Hyprland.dispatch("workspace " + workspace)
    }

    WorkspaceStrip {
        anchors.fill: parent
        labelText: "HYPR WS"
        valueText: hyprlandContext.pad2(hyprlandContext.activeWorkspace)
        subText: hyprlandContext.occupiedWorkspaces.length + " OCCUPIED"
        activeWorkspace: hyprlandContext.activeWorkspace
        rangeStart: hyprlandContext.rangeStart
        occupiedWorkspaces: hyprlandContext.occupiedWorkspaces
        compact: hyprlandContext.compact
        reducedMotion: hyprlandContext.reducedMotion
        textColor: hyprlandContext.textColor
        textSoft: hyprlandContext.textSoft
        textDim: hyprlandContext.textDim
        lineColor: hyprlandContext.lineColor
        accentColor: hyprlandContext.accentColor
        occupiedColor: hyprlandContext.occupiedColor
        emptyColor: hyprlandContext.emptyColor
        monoFont: hyprlandContext.monoFont
        onWorkspaceRequested: workspace => hyprlandContext.focusWorkspace(workspace)
    }
}
