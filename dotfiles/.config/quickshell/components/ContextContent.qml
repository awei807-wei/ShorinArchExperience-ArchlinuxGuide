import "../config" as Config
import QtQuick

Item {
    property var niriModel: null
    property var contextModel: null
    property var targetScreen: null
    property string screenName: ""
    property bool compact: false
    property bool reducedMotion: false
    property color textColor: Config.Theme.textPrimary
    property color textSoft: Config.Theme.textSecondary
    property color textDim: Config.Theme.textMuted
    property color lineColor: Config.Theme.outline
    property color accentColor: Config.Theme.accent
    property color occupiedColor: Config.Theme.textMuted
    property color emptyColor: Config.Theme.surfaceContainer
    property string monoFont: "JetBrains Mono"
}
