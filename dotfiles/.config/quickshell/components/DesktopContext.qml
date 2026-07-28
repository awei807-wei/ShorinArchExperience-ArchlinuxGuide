import QtQuick

ContextContent {
    id: desktopContext

    Row {
        anchors.fill: parent
        anchors.leftMargin: desktopContext.compact ? 8 : 11
        anchors.rightMargin: desktopContext.compact ? 8 : 11
        spacing: desktopContext.compact ? 8 : 10

        Item {
            width: desktopContext.compact ? 68 : 78
            height: parent.height

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    text: "DESKTOP"
                    color: desktopContext.textDim
                    font.family: desktopContext.monoFont
                    font.pixelSize: 6
                    font.letterSpacing: 0.9
                }
                Text {
                    text: desktopContext.contextModel ? desktopContext.contextModel.desktopName : "DESKTOP"
                    color: desktopContext.textColor
                    font.family: desktopContext.monoFont
                    font.pixelSize: 8
                    font.letterSpacing: 0.32
                }
                Text {
                    text: desktopContext.contextModel ? desktopContext.contextModel.sessionType : "SESSION"
                    color: desktopContext.textSoft
                    font.family: desktopContext.monoFont
                    font.pixelSize: 6
                    font.letterSpacing: 0.36
                }
            }
        }

        Rectangle {
            width: 1
            height: 18
            anchors.verticalCenter: parent.verticalCenter
            color: desktopContext.lineColor
        }

        Item {
            width: parent.width - (desktopContext.compact ? 68 : 78)
                - 1 - parent.spacing * 2
            height: parent.height

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    text: "CONTEXT"
                    color: desktopContext.textDim
                    font.family: desktopContext.monoFont
                    font.pixelSize: 6
                    font.letterSpacing: 0.72
                }
                Text {
                    text: "SESSION ACTIVE"
                    color: desktopContext.textSoft
                    font.family: desktopContext.monoFont
                    font.pixelSize: 7
                    font.letterSpacing: 0.2
                }
            }
        }
    }
}
