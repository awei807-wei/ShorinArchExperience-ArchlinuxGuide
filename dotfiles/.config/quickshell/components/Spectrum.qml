pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: spectrum

    property string bars: "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁"
    property bool active: false
    property bool reducedMotion: false
    property color barColor: "#767f84"
    property color topLineColor: Qt.rgba(180 / 255, 194 / 255, 202 / 255, 0.08)

    opacity: active ? 0.22 : 0.10

    function barHeight(index) {
        if (reducedMotion)
            return 6 + ((index * 5) % 7)

        const characters = "▁▂▃▄▅▆▇█"
        const value = bars.length > 0 ? bars[index % bars.length] : "▁"
        const level = Math.max(0, characters.indexOf(value))
        return 6 + Math.round(level * 16 / 7)
    }

    Row {
        anchors.fill: parent
        spacing: 2

        Repeater {
            model: 32

            Item {
                id: spectrumBar

                required property int index
                width: (spectrum.width - 62) / 32
                height: spectrum.height

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: spectrum.barHeight(spectrumBar.index)
                    color: spectrum.barColor
                    opacity: spectrum.active ? 0.5 : 0.25

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: spectrum.topLineColor
                    }

                    Behavior on height {
                        enabled: !spectrum.reducedMotion
                        NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
                    }
                }
            }
        }
    }

    Behavior on opacity {
        enabled: !spectrum.reducedMotion
        NumberAnimation { duration: 180 }
    }
}
