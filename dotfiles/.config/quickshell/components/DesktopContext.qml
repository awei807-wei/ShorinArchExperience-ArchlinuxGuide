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
                width: parent.width
                spacing: 3

                Text {
                    width: parent.width
                    text: "DESKTOP"
                    elide: Text.ElideRight
                    color: desktopContext.textDim
                    font.family: desktopContext.monoFont
                    font.pixelSize: 6
                    font.letterSpacing: 0.9
                }

                Text {
                    width: parent.width
                    text: desktopContext.contextModel ? desktopContext.contextModel.desktopName : "DESKTOP"
                    elide: Text.ElideRight
                    color: desktopContext.textColor
                    font.family: desktopContext.monoFont
                    font.pixelSize: 8
                    font.letterSpacing: 0.32
                }

                Text {
                    width: parent.width
                    text: desktopContext.contextModel ? desktopContext.contextModel.sessionType : "SESSION"
                    elide: Text.ElideRight
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
            width: parent.width - (desktopContext.compact ? 68 : 78) - 1 - parent.spacing * 2
            height: parent.height

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 4

                Text {
                    width: parent.width
                    text: "CONTEXT"
                    elide: Text.ElideRight
                    color: desktopContext.textDim
                    font.family: desktopContext.monoFont
                    font.pixelSize: 6
                    font.letterSpacing: 0.72
                }

                Text {
                    width: parent.width
                    text: "SESSION ACTIVE"
                    elide: Text.ElideRight
                    color: desktopContext.textSoft
                    font.family: desktopContext.monoFont
                    font.pixelSize: 7
                    font.letterSpacing: 0.2
                }

            }

        }

    }

}
