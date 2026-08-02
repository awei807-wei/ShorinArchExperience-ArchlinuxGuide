import "../config" as Config
import QtQuick

Rectangle {
    id: contextIsland

    property var contextState: null
    property var niriState: null
    property var screen: null
    property string contextModeOverride: ""
    property int responsiveLevel: 0
    property color surfaceColor: Config.Theme.surface
    property color borderColor: Config.Theme.outline
    property color highlightColor: Config.Theme.outlineVariant
    property color textColor: Config.Theme.textPrimary
    property color textSoft: Config.Theme.textSecondary
    property color textDim: Config.Theme.textMuted
    property color lineColor: Config.Theme.outline
    property color accentColor: Config.Theme.accent
    property color occupiedColor: Config.Theme.textMuted
    property color emptyColor: Config.Theme.surfaceContainer
    property string monoFont: "JetBrains Mono"
    readonly property bool compact: responsiveLevel >= 3
    readonly property bool ultraCompact: responsiveLevel >= 4
    readonly property string mode: contextModeOverride !== "" ? contextModeOverride : (contextState ? contextState.contextMode : "fallback")
    readonly property string screenName: screen && screen.name ? screen.name : ""

    implicitWidth: ultraCompact ? Config.BarTuning.contextUltraWidth : (compact ? Config.BarTuning.contextCompactWidth : Config.BarTuning.contextWidth)
    implicitHeight: Config.BarTuning.islandHeight
    color: surfaceColor
    border.color: borderColor
    border.width: Config.BarTuning.islandBorderWidth
    radius: Config.Theme.radiusMedium
    clip: true

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Config.BarTuning.islandTopHighlightHeight
        color: contextIsland.highlightColor
    }

    Rectangle {
        x: contextIsland.compact ? Config.BarTuning.contextAccentCompactX : Config.BarTuning.contextAccentX
        y: contextIsland.border.width
        width: contextIsland.compact ? Config.BarTuning.contextAccentCompactWidth : Config.BarTuning.contextAccentWidth
        height: Config.BarTuning.islandTopHighlightHeight
        color: contextIsland.accentColor
        opacity: Config.BarTuning.contextAccentOpacity
        z: 3
    }

    Loader {
        id: contextLoader

        function bindContextProperties() {
            if (!item)
                return ;

            item.niriModel = Qt.binding(function() {
                return contextIsland.niriState;
            });
            item.contextModel = Qt.binding(function() {
                return contextIsland.contextState;
            });
            item.targetScreen = Qt.binding(function() {
                return contextIsland.screen;
            });
            item.screenName = Qt.binding(function() {
                return contextIsland.screenName;
            });
            item.compact = Qt.binding(function() {
                return contextIsland.compact;
            });
            item.reducedMotion = Qt.binding(function() {
                return contextIsland.contextState ? contextIsland.contextState.reducedMotion : false;
            });
            item.textColor = Qt.binding(function() {
                return contextIsland.textColor;
            });
            item.textSoft = Qt.binding(function() {
                return contextIsland.textSoft;
            });
            item.textDim = Qt.binding(function() {
                return contextIsland.textDim;
            });
            item.lineColor = Qt.binding(function() {
                return contextIsland.lineColor;
            });
            item.accentColor = Qt.binding(function() {
                return contextIsland.accentColor;
            });
            item.occupiedColor = Qt.binding(function() {
                return contextIsland.occupiedColor;
            });
            item.emptyColor = Qt.binding(function() {
                return contextIsland.emptyColor;
            });
            item.monoFont = Qt.binding(function() {
                return contextIsland.monoFont;
            });
        }

        anchors.fill: parent
        source: {
            if (contextIsland.mode === "niri")
                return "NiriContext.qml";

            if (contextIsland.mode === "hyprland")
                return "HyprlandContext.qml";

            if (contextIsland.mode === "desktop")
                return "DesktopContext.qml";

            return "FallbackContext.qml";
        }
        onLoaded: bindContextProperties()
    }

}
