import QtQuick

ContourPod {
    id: root

    property bool compact: false
    property bool narrow: false
    property color ink: "#d9d3c9"
    property color muted: "#8e8d89"
    property color copper: "#7b6240"
    property color amber: "#dca651"

    sideInset: compact ? 14 : 18
    flushLeft: false
    flushRight: false
    borderColor: copper
    highlightColor: amber

    Row {
        anchors.fill: parent
        spacing: root.narrow ? 8 : (root.compact ? 13 : 18)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "23:08"
            color: root.ink
            font.family: "JetBrains Mono"
            font.pixelSize: root.narrow ? 22 : (root.compact ? 25 : 31)
            font.weight: Font.Light
            font.letterSpacing: -1.2
        }

        Rectangle {
            width: 1
            height: 45
            anchors.verticalCenter: parent.verticalCenter
            color: root.copper
            opacity: 0.68
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                text: "2025.08.08"
                color: root.ink
                font.family: "JetBrains Mono"
                font.pixelSize: root.narrow ? 8 : (root.compact ? 9 : 10)
            }
            Text {
                text: "SATURDAY  •  AUG"
                color: root.muted
                font.family: "JetBrains Mono"
                font.pixelSize: root.narrow ? 7 : (root.compact ? 8 : 9)
                font.letterSpacing: 0.8
            }
        }
    }
}
