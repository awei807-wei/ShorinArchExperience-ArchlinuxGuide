import QtQuick
import Quickshell
import "components"
import "config" as Config

ShellRoot {
    id: testRoot

    property int failureCount: 0
    property int phase: 0
    property int closeFinishedCount: 0
    property real reverseWidth: 0
    property real reverseHeight: 0
    property real reverseContent: 0

    function expect(condition, label) {
        if (condition)
            return
        failureCount += 1
        console.error("[RightPanelAnimationCheck] failed: " + label)
    }

    function near(actual, expected, tolerance) {
        return Math.abs(actual - expected) <= tolerance
    }

    function next(delay) {
        phaseTimer.interval = delay
        phaseTimer.restart()
    }

    function finish() {
        if (failureCount === 0) {
            console.log("[RightPanelAnimationCheck] PASS")
            Qt.exit(0)
        } else {
            console.error("[RightPanelAnimationCheck] FAIL count="
                          + failureCount)
            Qt.exit(1)
        }
    }

    QtObject {
        id: fakeShell

        property string nvmeUsage: "42"
        property string networkType: "ethernet"
        property bool wifiAvailable: false
        property bool wifiEnabled: false
        property string netSSID: "Wired"
        property string networkDevice: "eth0"
        property bool bluetoothAvailable: true
        property string btStatus: "OFF"
        property int volumePercent: 50
        property bool volumeMuted: false
        property int brightnessPercent: 60
        property var audioOutputOptions: []
        property int audioOutputCurrentIndex: -1
        property string audioOutputPlaceholder: "NO OUTPUT"
        property bool audioOutputsReady: false
        property var mprisPlayer: null
        property string mediaTitle: "No Media"
        property string mediaArtist: ""
        property bool mediaPlaying: false
        property string mediaArtUrl: ""

        function toggleWifi() {}
        function toggleBluetooth() {}
        function setVolume(value) {}
        function toggleMute() {}
        function selectAudioOutput(index) {}
        function setBrightness(value) {}
    }

    QtObject {
        id: fakeStore

        signal historyLoaded(var items, bool recovered, string warning)
        signal historyLoadFailed(string message)
        signal historyAppended()
        signal copySucceeded()
        signal copyFailed(string message)
        signal operationFailed(string operation, string message)
        signal historyCleared()

        function loadHistory() {
            historyLoaded([{
                "appName": "Kitty",
                "summary": "Animation fixture",
                "body": "One notification keeps History compact.",
                "urgency": "Normal",
                "timestamp": Date.now()
            }], false, "")
        }
        function copyEntry(entry) { copySucceeded() }
        function clearHistory() { historyCleared() }
    }

    Item {
        width: 640
        height: 760

        UnifiedRightPanel {
            id: panel

            width: 640
            height: 760
            controlTargetHeight: 760
            historyMaximumHeight: 640
            availablePanelHeight: 760
            shellRoot: fakeShell
            store: fakeStore
            reducedMotion: false
            onCloseAnimationFinished:
                testRoot.closeFinishedCount += 1
        }
    }

    Timer {
        id: phaseTimer

        onTriggered: {
            if (testRoot.phase === 0) {
                testRoot.expect(panel.widthProgress === 0,
                                "initial width collapsed")
                testRoot.expect(panel.heightProgress === 0,
                                "initial height collapsed")
                testRoot.expect(panel.contentProgress === 0,
                                "initial content hidden")
                testRoot.expect(testRoot.near(
                    panel.sizerItem.width,
                    Config.BarTuning.rightPanelNeckWidth
                        + Config.BarTuning.rightPanelFlare,
                    0.5), "collapsed width equals neck plus flare")
                panel.open = true
                testRoot.phase = 1
                testRoot.next(25)
                return
            }

            if (testRoot.phase === 1) {
                testRoot.expect(panel.widthProgress === 0,
                                "width waits for 40ms delay")
                testRoot.expect(panel.heightProgress === 0,
                                "height waits for 95ms delay")
                testRoot.expect(panel.contentProgress === 0,
                                "content waits for 180ms delay")
                testRoot.phase = 2
                testRoot.next(50)
                return
            }

            if (testRoot.phase === 2) {
                testRoot.expect(panel.widthProgress > 0,
                                "width expands before height")
                testRoot.expect(panel.widthProgress >= panel.heightProgress,
                                "width leads height during staged open")
                testRoot.expect(panel.contentProgress === 0,
                                "content still hidden at 75ms")
                testRoot.phase = 3
                testRoot.next(60)
                return
            }

            if (testRoot.phase === 3) {
                testRoot.expect(panel.widthProgress > 0,
                                "width remains in progress")
                testRoot.expect(panel.heightProgress > 0,
                                "height begins after width")
                testRoot.expect(panel.contentProgress === 0,
                                "content absent before 180ms")
                testRoot.phase = 4
                testRoot.next(75)
                return
            }

            if (testRoot.phase === 4) {
                testRoot.expect(panel.contentProgress > 0,
                                "content enters last")
                testRoot.phase = 5
                testRoot.next(180)
                return
            }

            if (testRoot.phase === 5) {
                testRoot.expect(testRoot.near(panel.widthProgress, 1, 0.01),
                                "open width completes")
                testRoot.expect(testRoot.near(panel.heightProgress, 1, 0.01),
                                "open height completes")
                testRoot.expect(testRoot.near(panel.contentProgress, 1, 0.01),
                                "open content completes")
                testRoot.expect(panel.controlBaseContentFits,
                                "Control cards fit before the footer without initial clipping")
                panel.page = 1
                testRoot.phase = 6
                testRoot.next(25)
                return
            }

            if (testRoot.phase === 6) {
                testRoot.expect(panel.open,
                                "page switch keeps shell open")
                testRoot.expect(panel.controlPageOpacity < 1,
                                "old page starts fading immediately")
                testRoot.expect(panel.historyPageOpacity < 1,
                                "new page does not appear instantly")
                testRoot.phase = 7
                testRoot.next(230)
                return
            }

            if (testRoot.phase === 7) {
                testRoot.expect(testRoot.near(panel.historyPageOpacity, 1, 0.03),
                                "history page fades in")
                testRoot.expect(testRoot.near(panel.controlPageOpacity, 0, 0.03),
                                "control page fades out")
                testRoot.expect(panel.animatedOpenHeight <= 520,
                                "single notification keeps History compact")
                panel.open = false
                testRoot.phase = 8
                testRoot.next(50)
                return
            }

            if (testRoot.phase === 8) {
                testRoot.expect(panel.contentProgress < 1,
                                "close removes content first")
                testRoot.expect(panel.heightProgress < 1,
                                "close begins shrinking height")
                testRoot.expect(testRoot.near(panel.widthProgress, 1, 0.02),
                                "width waits for close delay")
                testRoot.reverseWidth = panel.widthProgress
                testRoot.reverseHeight = panel.heightProgress
                testRoot.reverseContent = panel.contentProgress
                panel.open = true
                testRoot.expect(testRoot.near(panel.widthProgress,
                                             testRoot.reverseWidth, 0.001),
                                "reverse does not jump width")
                testRoot.expect(testRoot.near(panel.heightProgress,
                                             testRoot.reverseHeight, 0.001),
                                "reverse does not jump height")
                testRoot.expect(testRoot.near(panel.contentProgress,
                                             testRoot.reverseContent, 0.001),
                                "reverse does not jump content")
                testRoot.phase = 9
                testRoot.next(380)
                return
            }

            if (testRoot.phase === 9) {
                testRoot.expect(testRoot.near(panel.widthProgress, 1, 0.01),
                                "reverse reopen completes width")
                testRoot.expect(testRoot.near(panel.heightProgress, 1, 0.01),
                                "reverse reopen completes height")
                testRoot.expect(testRoot.near(panel.contentProgress, 1, 0.01),
                                "reverse reopen completes content")
                panel.open = false
                testRoot.phase = 10
                testRoot.next(260)
                return
            }

            if (testRoot.phase === 10) {
                testRoot.expect(testRoot.near(panel.widthProgress, 0, 0.01),
                                "close completes width")
                testRoot.expect(testRoot.near(panel.heightProgress, 0, 0.01),
                                "close completes height")
                testRoot.expect(testRoot.near(panel.contentProgress, 0, 0.01),
                                "close completes content")
                testRoot.expect(testRoot.closeFinishedCount === 1,
                                "only completed close emits lifecycle signal")
                panel.reducedMotion = true
                panel.open = true
                testRoot.expect(panel.widthProgress === 1
                                && panel.heightProgress === 1
                                && panel.contentProgress === 1,
                                "reduced motion opens immediately")
                panel.open = false
                testRoot.phase = 11
                testRoot.next(10)
                return
            }

            testRoot.expect(panel.widthProgress === 0
                            && panel.heightProgress === 0
                            && panel.contentProgress === 0,
                            "reduced motion closes immediately")
            testRoot.expect(testRoot.closeFinishedCount === 2,
                            "reduced motion close reports completion")
            testRoot.finish()
        }
    }

    Component.onCompleted: {
        testRoot.phase = 0
        testRoot.next(0)
    }
}
