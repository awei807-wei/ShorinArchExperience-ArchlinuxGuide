import Quickshell
import QtQuick
import "components/AudioOutputModel.js" as AudioOutputModel

ShellRoot {
    id: testRoot

    property int failureCount: 0

    function expect(condition, label) {
        if (condition)
            return

        failureCount += 1
        console.error("[AudioOutputModelCheck] failed: " + label)
    }

    function expectEqual(actual, expected, label) {
        if (actual === expected)
            return

        failureCount += 1
        console.error("[AudioOutputModelCheck] " + label
            + ": expected=" + expected + " actual=" + actual)
    }

    function runChecks() {
        const nodes = [
            { "id": 42, "name": "alsa_output.usb-b", "nickname": "USB DAC", "description": "USB Audio", "audio": {}, "isSink": true, "isStream": false },
            { "id": 9, "name": "alsa_output.hdmi-a", "nickname": "HDMI", "description": "Display Audio", "audio": {}, "isSink": true, "isStream": false },
            { "id": 10, "name": "alsa_output.hdmi-b", "nickname": "HDMI", "description": "Display Audio", "audio": {}, "isSink": true, "isStream": false },
            { "id": 7, "name": "alsa_output.internal", "nickname": "", "description": "Built-in Audio", "audio": {}, "isSink": true, "isStream": false },
            { "id": 80, "name": "Firefox", "nickname": "Firefox", "description": "Browser stream", "audio": {}, "isSink": true, "isStream": true },
            { "id": 81, "name": "alsa_input.internal", "nickname": "Microphone", "description": "Built-in Mic", "audio": {}, "isSink": false, "isStream": false },
            { "id": 82, "name": "camera", "nickname": "Camera", "description": "Camera", "audio": null, "isSink": true, "isStream": false }
        ]

        const outputOptions = AudioOutputModel.options(nodes)
        expectEqual(outputOptions.length, 4, "filters to hardware audio sinks")
        expectEqual(outputOptions[0].label, "Built-in Audio", "uses description fallback and sorts labels")
        expectEqual(outputOptions[1].label, "HDMI · alsa_output.hdmi-a", "disambiguates first duplicate")
        expectEqual(outputOptions[2].label, "HDMI · alsa_output.hdmi-b", "disambiguates second duplicate")
        expectEqual(outputOptions[3].label, "USB DAC", "prefers nickname")
        expectEqual(AudioOutputModel.currentIndex(outputOptions, { "id": 10 }), 2,
                    "matches the current sink by stable PipeWire id")
        expectEqual(AudioOutputModel.currentIndex(outputOptions, null), -1,
                    "handles a temporarily missing default sink")
        expect(!AudioOutputModel.isOutputNode(nodes[4]), "rejects application streams")
        expect(!AudioOutputModel.isOutputNode(nodes[5]), "rejects audio sources")
        expect(!AudioOutputModel.isOutputNode(nodes[6]), "rejects non-audio nodes")

        if (failureCount === 0) {
            console.log("[AudioOutputModelCheck] PASS")
            Qt.exit(0)
        } else {
            console.error("[AudioOutputModelCheck] FAIL count=" + failureCount)
            Qt.exit(1)
        }
    }

    Timer {
        interval: 0
        running: true
        onTriggered: Qt.callLater(testRoot.runChecks)
    }
}
