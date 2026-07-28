import "../config" as Config
import QtQuick

ContextContent {
    id: fallbackContext

    Row {
        anchors.fill: parent
        anchors.leftMargin: fallbackContext.compact ? Config.BarTuning.desktopContextCompactPadding : Config.BarTuning.desktopContextPadding
        anchors.rightMargin: anchors.leftMargin
        spacing: fallbackContext.compact ? Config.BarTuning.desktopContextCompactGap : Config.BarTuning.desktopContextGap

        Item {
            width: fallbackContext.compact ? Config.BarTuning.desktopContextCompactMetaWidth : Config.BarTuning.desktopContextMetaWidth
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
                    font.pixelSize: Config.BarTuning.desktopSecondaryFontSize
                    font.letterSpacing: 0.9
                }

                Text {
                    width: parent.width
                    text: fallbackContext.contextModel ? fallbackContext.contextModel.sessionType : "GENERIC"
                    elide: Text.ElideRight
                    color: fallbackContext.textColor
                    font.family: fallbackContext.monoFont
                    font.pixelSize: Config.BarTuning.desktopPrimaryFontSize
                    font.letterSpacing: 0.32
                }

                Text {
                    width: parent.width
                    text: "FALLBACK"
                    elide: Text.ElideRight
                    color: fallbackContext.textSoft
                    font.family: fallbackContext.monoFont
                    font.pixelSize: Config.BarTuning.desktopSecondaryFontSize
                    font.letterSpacing: 0.36
                }

            }

        }

        Rectangle {
            width: 1
            height: Config.BarTuning.contextDividerHeight
            anchors.verticalCenter: parent.verticalCenter
            color: fallbackContext.lineColor
        }

        Item {
            width: parent.width - (fallbackContext.compact ? Config.BarTuning.desktopContextCompactMetaWidth : Config.BarTuning.desktopContextMetaWidth) - Config.BarTuning.islandBorderWidth - parent.spacing * 2
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
                    font.pixelSize: Config.BarTuning.desktopSecondaryFontSize
                    font.letterSpacing: 0.72
                }

                Text {
                    width: parent.width
                    text: fallbackContext.contextModel ? fallbackContext.contextModel.desktopName : "DESKTOP"
                    elide: Text.ElideRight
                    color: fallbackContext.textSoft
                    font.family: fallbackContext.monoFont
                    font.pixelSize: Config.BarTuning.desktopContextFontSize
                    font.letterSpacing: 0.2
                }

            }

        }

    }

}
