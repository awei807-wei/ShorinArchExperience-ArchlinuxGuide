pragma ComponentBehavior: Bound

import QtQuick
import "../config" as Config

Item {
    id: spectrum

    property string bars: "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁"
    property bool active: false
    property bool reducedMotion: false
    property color barColor: Config.Theme.textMuted
    property color topLineColor: Config.Theme.outlineVariant
    readonly property int barCount: Config.BarTuning.spectrumBarCount
    readonly property real barWidth: Math.max(1, Math.min(
        Config.BarTuning.spectrumBarWidth,
        width / Math.max(1, barCount)
    ))
    readonly property real barGap: barCount > 1
        ? Math.max(0, (width - barCount * barWidth) / (barCount - 1))
        : 0

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
                width: spectrum.barWidth
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
                        NumberAnimation { duration: Config.Theme.animNormal; easing.type: Easing.OutQuad }
                    }
                }
            }
        }
    }

    Behavior on opacity {
        enabled: !spectrum.reducedMotion
        NumberAnimation { duration: Config.Theme.animNormal }
    }
}
