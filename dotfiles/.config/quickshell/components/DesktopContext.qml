import "../config" as Config
import QtQuick

ContextContent {
    id: desktopContext

    Row {
        anchors.fill: parent
        anchors.leftMargin: desktopContext.compact ? Config.BarTuning.desktopContextCompactPadding : Config.BarTuning.desktopContextPadding
        anchors.rightMargin: anchors.leftMargin
        spacing: desktopContext.compact ? Config.BarTuning.desktopContextCompactGap : Config.BarTuning.desktopContextGap

        Item {
            width: desktopContext.compact ? Config.BarTuning.desktopContextCompactMetaWidth : Config.BarTuning.desktopContextMetaWidth
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
                    font.pixelSize: Config.Theme.fontTiny
                    font.letterSpacing: 0.9
                }

                Text {
                    width: parent.width
                    text: desktopContext.contextModel ? desktopContext.contextModel.desktopName : "DESKTOP"
                    elide: Text.ElideRight
                    color: desktopContext.textColor
                    font.family: desktopContext.monoFont
                    font.pixelSize: Config.Theme.fontTiny
                    font.letterSpacing: 0.32
                }

                Text {
                    width: parent.width
                    text: desktopContext.contextModel ? desktopContext.contextModel.sessionType : "SESSION"
                    elide: Text.ElideRight
                    color: desktopContext.textSoft
                    font.family: desktopContext.monoFont
                    font.pixelSize: Config.Theme.fontTiny
                    font.letterSpacing: 0.36
                }

            }

        }

        Rectangle {
            width: 1
            height: Config.BarTuning.contextDividerHeight
            anchors.verticalCenter: parent.verticalCenter
            color: desktopContext.lineColor
        }

        Item {
            width: parent.width - (desktopContext.compact ? Config.BarTuning.desktopContextCompactMetaWidth : Config.BarTuning.desktopContextMetaWidth) - Config.BarTuning.islandBorderWidth - parent.spacing * 2
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
                    font.pixelSize: Config.Theme.fontTiny
                    font.letterSpacing: 0.72
                }

                Text {
                    width: parent.width
                    text: "SESSION ACTIVE"
                    elide: Text.ElideRight
                    color: desktopContext.textSoft
                    font.family: desktopContext.monoFont
                    font.pixelSize: Config.Theme.fontTiny
                    font.letterSpacing: 0.2
                }

            }

        }

    }

}
