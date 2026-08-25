import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "components"
import "config" as Config

ShellRoot {
    id: testRoot

    property int failureCount: 0
    property int selectedIndex: -1
    property var outputOptions: [
        { "label": "Built-in Audio" },
        { "label": "USB DAC" },
        { "label": "Very Long Display Audio Device Name For Elision" }
    ]

    function expect(condition, label) {
        if (condition)
            return

        failureCount += 1
        console.error("[AudioOutputSelectorCheck] failed: " + label)
    }

    function expectEqual(actual, expected, label) {
        if (actual === expected)
            return

        failureCount += 1
        console.error("[AudioOutputSelectorCheck] " + label
            + ": expected=" + expected + " actual=" + actual)
    }

    function finish() {
        testWindow.close()
        if (failureCount === 0) {
            console.log("[AudioOutputSelectorCheck] PASS")
            Qt.exit(0)
        } else {
            console.error("[AudioOutputSelectorCheck] FAIL count=" + failureCount)
            Qt.exit(1)
        }
    }

    Window {
        id: testWindow

        width: 520
        height: 320
        visible: true
        color: "#101010"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 12

            ControlCenterSlider {
                id: volumeSlider

                Layout.fillWidth: true
                icon: "󰕾"
                toolTip: "音量"
                value: 64
                reducedMotion: false
                selectorVisible: true
                selectorModel: testRoot.outputOptions
                selectorCurrentIndex: 2
                onSelectorRequested: index => testRoot.selectedIndex = index
            }

            ControlCenterSlider {
                id: emptySlider

                Layout.fillWidth: true
                icon: "󰕾"
                value: 20
                selectorVisible: true
                selectorModel: []
                selectorCurrentIndex: -1
                selectorEnabled: false
            }

            Item { Layout.fillHeight: true }
        }
    }

    Timer {
        id: expansionTimer
        interval: 190
        onTriggered: {
            expect(volumeSlider.selectorRevealHeight > 80,
                   "device choices expand inside the volume card")
            expect(volumeSlider.Layout.preferredHeight > 140,
                   "expanded volume card reserves layout height")
            volumeSlider.chooseSelectorIndex(1)
            expectEqual(selectedIndex, 1, "selection forwards the chosen index")
            expect(!volumeSlider.selectorExpanded, "selection starts collapsing the device area")
            collapseTimer.start()
        }
    }

    Timer {
        id: collapseTimer
        interval: 190
        onTriggered: {
            expect(volumeSlider.selectorRevealHeight < 0.5,
                   "selection hides the expanded device area")
            expectEqual(Math.round(volumeSlider.Layout.preferredHeight),
                        Config.BarTuning.rightPanelControlSliderHeight,
                        "collapsed volume card returns to its original height")
            finish()
        }
    }

    Timer {
        interval: 0
        running: true
        onTriggered: Qt.callLater(() => {
            expectEqual(volumeSlider.selectorCount, 3, "selector exposes all device options")
            expectEqual(volumeSlider.selectorSelectedLabel,
                        "Very Long Display Audio Device Name For Elision",
                        "current device label follows the selected index")
            expectEqual(emptySlider.selectorCount, 0, "empty device state remains safe")
            expect(!emptySlider.selectorExpanded, "disabled empty selector stays collapsed")
            volumeSlider.selectorExpanded = true
            expansionTimer.start()
        })
    }
}
