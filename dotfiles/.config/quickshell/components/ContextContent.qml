import QtQuick

Item {
    property var niriModel: null
    property var contextModel: null
    property var targetScreen: null
    property string screenName: ""
    property bool compact: false
    property bool reducedMotion: false
    property color textColor: "#e7e9ea"
    property color textSoft: "#a7abad"
    property color textDim: "#6d7376"
    property color lineColor: Qt.rgba(1, 1, 1, 0.10)
    property color accentColor: "#8fb3c5"
    property color occupiedColor: "#747b7f"
    property color emptyColor: "#3c4143"
    property string monoFont: "JetBrains Mono"
}
