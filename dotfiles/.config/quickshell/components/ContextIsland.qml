import QtQuick

Rectangle {
    id: contextIsland

    property var contextState: null
    property var niriState: null
    property var screen: null
    property string contextModeOverride: ""
    property int responsiveLevel: 0
    property color surfaceColor: Qt.rgba(10 / 255, 12 / 255, 13 / 255, 0.94)
    property color borderColor: Qt.rgba(1, 1, 1, 0.085)
    property color highlightColor: Qt.rgba(1, 1, 1, 0.045)
    property color textColor: "#e7e9ea"
    property color textSoft: "#a7abad"
    property color textDim: "#6d7376"
    property color lineColor: Qt.rgba(1, 1, 1, 0.10)
    property color accentColor: "#8fb3c5"
    property color occupiedColor: "#747b7f"
    property color emptyColor: "#3c4143"
    property string monoFont: "JetBrains Mono"

    readonly property bool compact: responsiveLevel >= 3
    readonly property bool ultraCompact: responsiveLevel >= 4
    readonly property string mode: contextModeOverride !== ""
        ? contextModeOverride : (contextState ? contextState.contextMode : "fallback")
    readonly property string screenName: screen && screen.name ? screen.name : ""

    implicitWidth: ultraCompact ? 185 : (compact ? 200 : 238)
    implicitHeight: 38
    color: surfaceColor
    border.color: borderColor
    border.width: 1
    radius: 3
    clip: true

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: contextIsland.highlightColor
    }

    Rectangle {
        x: contextIsland.compact ? 9 : 12
        y: contextIsland.border.width
        width: contextIsland.compact ? 16 : 20
        height: 1
        color: contextIsland.accentColor
        opacity: 0.9
        z: 3
    }

    Loader {
        id: contextLoader
        anchors.fill: parent

        function bindContextProperties() {
            if (!item)
                return

            item.niriModel = Qt.binding(function() { return contextIsland.niriState })
            item.contextModel = Qt.binding(function() { return contextIsland.contextState })
            item.targetScreen = Qt.binding(function() { return contextIsland.screen })
            item.screenName = Qt.binding(function() { return contextIsland.screenName })
            item.compact = Qt.binding(function() { return contextIsland.compact })
            item.reducedMotion = Qt.binding(function() {
                return contextIsland.contextState ? contextIsland.contextState.reducedMotion : false
            })
            item.textColor = Qt.binding(function() { return contextIsland.textColor })
            item.textSoft = Qt.binding(function() { return contextIsland.textSoft })
            item.textDim = Qt.binding(function() { return contextIsland.textDim })
            item.lineColor = Qt.binding(function() { return contextIsland.lineColor })
            item.accentColor = Qt.binding(function() { return contextIsland.accentColor })
            item.occupiedColor = Qt.binding(function() { return contextIsland.occupiedColor })
            item.emptyColor = Qt.binding(function() { return contextIsland.emptyColor })
            item.monoFont = Qt.binding(function() { return contextIsland.monoFont })
        }

        source: {
            if (contextIsland.mode === "niri")
                return "NiriContext.qml"
            if (contextIsland.mode === "hyprland")
                return "HyprlandContext.qml"
            if (contextIsland.mode === "desktop")
                return "DesktopContext.qml"
            return "FallbackContext.qml"
        }
        onLoaded: bindContextProperties()
    }
}
