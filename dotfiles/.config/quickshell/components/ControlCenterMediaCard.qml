import QtQuick
import QtQuick.Layouts
import "../config" as Config

Rectangle {
    id: root

    required property var shellRoot
    property color surfaceColor: "#1c1c1c"
    property color elevatedColor: "#252525"
    property color textColor: "#d0d0d0"
    property color mutedColor: "#707070"
    property color accentColor: "#8fb3c5"
    property color dangerColor: Config.Theme.danger
    property bool reducedMotion: false

    Layout.fillWidth: true
    Layout.preferredHeight: Config.BarTuning.rightPanelControlMediaHeight
    radius: Config.Theme.radiusMedium
    color: root.surfaceColor
    border.color: Config.Theme.outlineVariant

    RowLayout {
        id: mediaContent
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12
        visible: root.shellRoot.mprisPlayer !== null

        Rectangle {
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            radius: Config.Theme.radiusMedium
            clip: true
            color: root.elevatedColor

            Image {
                id: albumArt
                anchors.fill: parent
                source: root.shellRoot.mediaArtUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Text {
                anchors.centerIn: parent
                visible: albumArt.status !== Image.Ready
                text: "󰝚"
                font.family: "Material Design Icons"
                font.pixelSize: 28
                color: root.mutedColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Text {
                Layout.fillWidth: true
                text: root.shellRoot.mediaTitle
                elide: Text.ElideRight
                font.family: "JetBrains Mono"
                font.pixelSize: 13
                font.weight: Font.Bold
                color: root.textColor
            }
            Text {
                Layout.fillWidth: true
                text: root.shellRoot.mediaArtist
                elide: Text.ElideRight
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                color: root.mutedColor
            }
        }

        ControlCenterHeaderButton {
            icon: root.shellRoot.mediaPlaying ? "󰏤" : "󰐊"
            toolTip: root.shellRoot.mediaPlaying ? "Pause" : "Play"
            emphasized: true
            accentColor: root.accentColor
            elevatedColor: root.elevatedColor
            surfaceColor: root.surfaceColor
            textColor: root.textColor
            dangerColor: root.dangerColor
            reducedMotion: root.reducedMotion
            onClicked: {
                if (root.shellRoot.mprisPlayer)
                    root.shellRoot.mprisPlayer.togglePlaying()
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !mediaContent.visible
        text: "NO ACTIVE MEDIA"
        font.family: "JetBrains Mono"
        font.pixelSize: 11
        font.letterSpacing: 1
        color: root.mutedColor
    }
}
