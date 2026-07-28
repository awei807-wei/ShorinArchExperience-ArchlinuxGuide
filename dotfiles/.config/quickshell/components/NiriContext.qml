import QtQuick

ContextContent {
    id: niriContext

    readonly property var currentWorkspace: niriModel
        ? niriModel.workspaceForOutput(screenName) : null
    readonly property int activeWorkspace: currentWorkspace
        ? currentWorkspace.idx : 1
    readonly property int rangeStart: Math.floor((activeWorkspace - 1) / 5) * 5 + 1
    readonly property int rangeEnd: rangeStart + 4
    readonly property var occupiedWorkspaces: niriModel
        ? niriModel.occupiedIndexes(screenName) : []

    function pad2(value) {
        return String(value).padStart(2, "0")
    }

    WorkspaceStrip {
        anchors.fill: parent
        labelText: "NIRI RANGE"
        valueText: niriContext.pad2(niriContext.rangeStart) + "–"
            + niriContext.pad2(niriContext.rangeEnd)
        subText: niriContext.niriModel && niriContext.niriModel.errorMessage !== ""
            ? niriContext.niriModel.errorMessage : "WS " + niriContext.pad2(niriContext.activeWorkspace)
        activeWorkspace: niriContext.activeWorkspace
        rangeStart: niriContext.rangeStart
        occupiedWorkspaces: niriContext.occupiedWorkspaces
        compact: niriContext.compact
        reducedMotion: niriContext.reducedMotion
        textColor: niriContext.textColor
        textSoft: niriContext.textSoft
        textDim: niriContext.textDim
        lineColor: niriContext.lineColor
        accentColor: niriContext.accentColor
        occupiedColor: niriContext.occupiedColor
        emptyColor: niriContext.emptyColor
        monoFont: niriContext.monoFont
        onWorkspaceRequested: workspace => {
            if (niriContext.niriModel)
                niriContext.niriModel.focusWorkspace(workspace, niriContext.screenName)
        }
    }
}
