pragma ComponentBehavior: Bound

import QtQuick
import "../config" as Config

Item {
    id: spectrum

    property string bars: "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁"
    property bool active: false
    property bool reducedMotion: false
    property color barColor: "#767f84"
    property color topLineColor: Qt.rgba(180 / 255, 194 / 255, 202 / 255, 0.08)
    readonly property int barCount: Config.BarTuning.spectrumBarCount
    readonly property int barGap: Config.BarTuning.spectrumBarGap

    opacity: active
        ? Config.BarTuning.spectrumActiveOpacity : Config.BarTuning.spectrumInactiveOpacity

    function barHeight(index) {
        if (reducedMotion)
            return Config.BarTuning.spectrumMinBarHeight + ((index * 5) % 7)

        const characters = "▁▂▃▄▅▆▇█"
        const value = bars.length > 0 ? bars[index % bars.length] : "▁"
        const level = Math.max(0, characters.indexOf(value))
        return Config.BarTuning.spectrumMinBarHeight
            + Math.round(level * Config.BarTuning.spectrumBarHeightRange / 7)
    }

    Row {
        anchors.fill: parent
        spacing: spectrum.barGap

        Repeater {
            model: spectrum.barCount

            Item {
                id: spectrumBar

                required property int index
                width: Math.max(1, (spectrum.width
                    - (spectrum.barCount - 1) * spectrum.barGap) / spectrum.barCount)
                height: spectrum.height

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: spectrum.barHeight(spectrumBar.index)
                    color: spectrum.barColor
                    opacity: spectrum.active
                        ? Config.BarTuning.spectrumActiveBarOpacity
                        : Config.BarTuning.spectrumInactiveBarOpacity

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
