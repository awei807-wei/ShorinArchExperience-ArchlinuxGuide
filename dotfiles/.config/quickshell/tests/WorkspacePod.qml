import QtQuick

ContourPod {
    id: root

    property bool compact: false
    property bool narrow: false
    property color ink: "#d9d3c9"
    property color muted: "#8e8d89"
    property color dim: "#5f625f"
    property color copper: "#7b6240"
    property color amber: "#dca651"

    sideInset: compact ? 14 : 18
    flushLeft: true
    flushRight: false
    topInset: 11
    borderColor: copper
    highlightColor: amber

    Row {
        anchors.fill: parent
        spacing: root.compact ? 12 : 16

        Column {
            width: root.compact ? 45 : 54
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                text: "RANGE"
                color: root.muted
                font.family: "JetBrains Mono"
                font.pixelSize: root.compact ? 8 : 9
                font.letterSpacing: 0.8
            }
            Text {
                text: "01–05"
                color: root.ink
                font.family: "JetBrains Mono"
                font.pixelSize: root.compact ? 12 : 14
                font.weight: Font.Medium
            }
            Text {
                text: "WS 03"
                color: root.amber
                font.family: "JetBrains Mono"
                font.pixelSize: root.compact ? 8 : 9
                font.letterSpacing: 0.5
            }
        }

        Rectangle {
            width: 1
            height: 43
            anchors.verticalCenter: parent.verticalCenter
            color: root.copper
            opacity: 0.7
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7
            width: parent.width - (root.compact ? 72 : 88)

            Text {
                text: "WORKSPACE"
                color: root.dim
                font.family: "JetBrains Mono"
                font.pixelSize: 8
                font.letterSpacing: 1.1
            }

            Row {
                width: parent.width
                spacing: root.narrow ? 5 : (root.compact ? 8 : 12)

                Repeater {
                    model: ["01", "02", "03", "04", "05"]
                    delegate: Column {
                        required property string modelData
                        width: Math.max(root.narrow ? 14 : 20,
                                        (parent.width - 4 * (root.narrow ? 5 : (root.compact ? 8 : 12))) / 5)
                        spacing: 4

                        Text {
                            width: parent.width
                            text: modelData
                            horizontalAlignment: Text.AlignHCenter
                            color: modelData === "03" ? root.ink : root.muted
                            font.family: "JetBrains Mono"
                            font.pixelSize: root.compact ? 11 : 12
                        }
                        Rectangle {
                            width: modelData === "03" ? parent.width : Math.min(14, parent.width)
                            height: modelData === "03" ? 2 : 1
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: modelData === "03" ? root.amber : root.dim
                            opacity: modelData === "03" ? 1 : 0.48
                        }
                    }
                }
            }
        }
    }
}
