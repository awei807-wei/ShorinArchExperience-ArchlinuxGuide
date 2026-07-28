import QtQuick

ContextContent {
    id: fallbackContext

    Row {
        anchors.fill: parent
        anchors.leftMargin: fallbackContext.compact ? 8 : 11
        anchors.rightMargin: fallbackContext.compact ? 8 : 11
        spacing: fallbackContext.compact ? 8 : 10

        Item {
            width: fallbackContext.compact ? 68 : 78
            height: parent.height

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 3

                Text {
                    width: parent.width
                    text: "SESSION"
                    elide: Text.ElideRight
                    color: fallbackContext.textDim
                    font.family: fallbackContext.monoFont
                    font.pixelSize: 6
                    font.letterSpacing: 0.9
                }

                Text {
                    width: parent.width
                    text: fallbackContext.contextModel ? fallbackContext.contextModel.sessionType : "GENERIC"
                    elide: Text.ElideRight
                    color: fallbackContext.textColor
                    font.family: fallbackContext.monoFont
                    font.pixelSize: 8
                    font.letterSpacing: 0.32
                }

                Text {
                    width: parent.width
                    text: "FALLBACK"
                    elide: Text.ElideRight
                    color: fallbackContext.textSoft
                    font.family: fallbackContext.monoFont
                    font.pixelSize: 6
                    font.letterSpacing: 0.36
                }

            }

        }

        Rectangle {
            width: 1
            height: 18
            anchors.verticalCenter: parent.verticalCenter
            color: fallbackContext.lineColor
        }

        Item {
            width: parent.width - (fallbackContext.compact ? 68 : 78) - 1 - parent.spacing * 2
            height: parent.height

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 4

                Text {
                    width: parent.width
                    text: "ENVIRONMENT"
                    elide: Text.ElideRight
                    color: fallbackContext.textDim
                    font.family: fallbackContext.monoFont
                    font.pixelSize: 6
                    font.letterSpacing: 0.72
                }

                Text {
                    width: parent.width
                    text: fallbackContext.contextModel ? fallbackContext.contextModel.desktopName : "DESKTOP"
                    elide: Text.ElideRight
                    color: fallbackContext.textSoft
                    font.family: fallbackContext.monoFont
                    font.pixelSize: 7
                    font.letterSpacing: 0.2
                }

            }

        }

    }

}
