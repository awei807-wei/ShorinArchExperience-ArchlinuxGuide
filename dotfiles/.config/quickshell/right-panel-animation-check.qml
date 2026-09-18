import QtQuick
import Quickshell
import "components"
import "config" as Config

ShellRoot {
    id: testRoot

    property int failureCount: 0
    property int phase: 0
    property real reverseProgress: 0
    property real sampledProgress: 0
    property real stablePageHeight: 0
    property real stableViewportHeight: 0

    function expect(condition, label) {
        if (condition)
            return
        failureCount += 1
        console.error("[RightPanelAnimationCheck] failed: " + label)
    }

    function near(actual, expected, tolerance) {
        return Math.abs(actual - expected) <= tolerance
    }

    function expectedBody(progress) {
        return Math.max(0, Math.min(1,
            (progress - Config.BarTuning.panelBodyStartProgress)
            / (1 - Config.BarTuning.panelBodyStartProgress)))
    }

    function expectedContent(progress) {
        return Math.max(0, Math.min(1,
            (progress - Config.BarTuning.panelContentStartProgress)
            / (1 - Config.BarTuning.panelContentStartProgress)))
    }

    function expectedWidth(progress) {
        return Math.round(panel.collapsedWidth
            + (panel.width - panel.collapsedWidth) * progress)
    }

    function expectedHeight(progress) {
        return Math.round(panel.safeRevealHeight
            + (panel.openHeight - panel.safeRevealHeight)
                * expectedBody(progress))
    }

    // 阶段门槛自洽：Bar-only 段 body/content 为 0，body-only 段 content 为 0
    function expectStageConsistency(progress, label) {
        if (progress < Config.BarTuning.panelBodyStartProgress) {
            expect(panel.bodyProgress === 0 && panel.contentProgress === 0
                   && panel.inputRegion.height === 0,
                   label + " Bar-only stage exposes no body or input")
        } else if (progress < Config.BarTuning.panelContentStartProgress) {
            expect(panel.bodyProgress > 0 && panel.contentProgress === 0,
                   label + " body precedes content")
        } else {
            expect(panel.bodyProgress > panel.contentProgress,
                   label + " content stays behind body")
        }
    }

    function expectGeometry(progress, label) {
        controller.rightPanelProgress = progress
        const body = expectedBody(progress)
        const content = expectedContent(progress)

        expect(near(panel.normalizedShellProgress, progress, 0.0001),
               label + " consumes shared progress")
        expect(near(panel.bodyProgress, body, 0.0001),
               label + " derives body progress")
        expect(near(panel.contentProgress, content, 0.0001),
               label + " derives content progress")
        expect(near(panel.sizerItem.width, expectedWidth(progress), 0.5),
               label + " viewport width")
        expect(near(panel.sizerItem.height, expectedHeight(progress), 0.5),
               label + " viewport height")
        expect(near(panel.sizerItem.opacity, body, 0.0001),
               label + " body opacity")
        expect(near(panel.inputRegion.x, panel.sizerItem.x, 0.01)
               && near(panel.inputRegion.width, panel.sizerItem.width, 0.01),
               label + " input follows viewport width")
        expect(near(panel.inputRegion.y,
                    Config.BarTuning.rightPanelFlare, 0.01),
               label + " input leaves overlap flare to Bar")
        expect(near(panel.inputRegion.height,
                    body > 0.001
                        ? panel.sizerItem.height
                            - Config.BarTuning.rightPanelFlare
                        : 0,
                    0.01),
               label + " input follows visible body")

        const shape = panel.shapeItem
        expect(near(shape.width, panel.width, 0.01)
               && near(shape.height, panel.openHeight, 0.01),
               label + " shell keeps final dimensions")
        expect(near(shape.bodyWidth, panel.width, 0.01)
               && near(shape.bodyLeft, 0, 0.01),
               label + " shell body never deforms")
        expect(near(shape.effectiveRadius,
                    Config.BarTuning.rightPanelRadius, 0.01),
               label + " shell radius never collapses")
        expect(near(shape.neckLeft,
                    panel.width - panel.normalizedTargetRightWidth,
                    0.01), label + " shell neck stays aligned")
        if (progress > 0) {
            expect(near(progressBar.animatedRightContourWidth,
                        panel.currentNeckWidth, 0.01),
                   label + " Bar and shell share the same neck width")
            expect(near(panel.shellHorizontalOffset,
                        panel.normalizedTargetRightWidth
                            - panel.currentNeckWidth, 0.01),
                   label + " fixed shell translates without reshaping")
            expect(near(shape.neckLeft + panel.shellHorizontalOffset,
                        panel.width - panel.currentNeckWidth, 0.01),
                   label + " translated flare meets the Bar edge")
        }
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

    RightPanelController {
        id: controller

        animationDuration: 200
        hideDelay: 20
        baseRightWidth: 240
    }

    Bar {
        id: progressBar

        width: 1280
        height: Config.BarTuning.barHeight
        visible: false
        rightPanelOpen: controller.open
        rightPanelProgress: controller.progress
        rightPanelBaseWidth: controller.baseRightWidth
        rightPanelTargetWidth: controller.targetRightWidth
    }

    Item {
        width: 560
        height: 760

        UnifiedRightPanel {
            id: panel

            width: 560
            height: 760
            shellRoot: fakeShell
            store: fakeStore
            open: controller.open
            page: controller.page
            shellProgress: controller.progress
            baseRightWidth: controller.baseRightWidth
            targetRightWidth: controller.targetRightWidth
            reducedMotion: controller.reducedMotion
            prewarmDuration: 0
            onCloseRequested: controller.close()
            onPageRequested: targetPage => controller.showPage(targetPage)
        }
    }

    Timer {
        id: phaseTimer

        onTriggered: {
            if (testRoot.phase === 0) {
                expect(panel.safeRevealHeight === 54,
                       "safe reveal height is flare plus two radii plus overshoot")
                expectGeometry(0, "collapsed")
                expect(panel.sizerItem.opacity === 0
                       && panel.inputRegion.height === 0,
                       "collapsed body and input are not exposed")
                expectGeometry(0.05, "bar-only stage")
                expect(panel.bodyProgress === 0
                       && panel.contentProgress === 0,
                       "first ten percent reveals only the Bar")
                expectGeometry(0.2, "body-only stage")
                expect(panel.bodyProgress > 0
                       && panel.contentProgress === 0,
                       "body precedes content without deforming shell")
                expectGeometry(0.75, "content stage")
                expect(panel.bodyProgress > panel.contentProgress
                       && panel.contentProgress > 0,
                       "content remains visually delayed")
                expectGeometry(1, "expanded")

                controller.targetRightWidth = 278
                expectGeometry(0.5, "constrained neck")
                expect(panel.normalizedTargetRightWidth === 278,
                       "panel honors the Bar's constrained target neck")
                controller.targetRightWidth =
                    Config.BarTuning.rightPanelNeckWidth

                controller.rightPanelProgress = 0
                controller.showPage(controller.controlsPage)
                phase = 1
                next(30)
                return
            }

            // 真实动画采样：OutCubic 起步即有位移，采样点不再假定固定
            // 阶段，只验证进度单调递增、几何派生一致且各阶段门槛自洽。
            if (testRoot.phase === 1) {
                expect(controller.progress > 0 && controller.progress < 1,
                       "real animation starts moving immediately")
                expectStageConsistency(controller.progress, "early animation")
                expectGeometry(controller.progress, "early animation")
                sampledProgress = controller.progress
                phase = 2
                next(50)
                return
            }

            if (testRoot.phase === 2) {
                expect(controller.progress > sampledProgress,
                       "real animation keeps advancing")
                expectStageConsistency(controller.progress, "mid animation")
                expectGeometry(controller.progress, "mid animation")
                sampledProgress = controller.progress
                phase = 3
                next(55)
                return
            }

            if (testRoot.phase === 3) {
                expect(controller.progress >= sampledProgress,
                       "real animation never reverses while opening")
                expect(controller.progress
                           > Config.BarTuning.panelContentStartProgress
                       && panel.contentProgress > 0,
                       "content begins from shared progress")
                expectGeometry(controller.progress, "content animation")
                phase = 4
                next(100)
                return
            }

            if (testRoot.phase === 4) {
                expect(near(controller.progress, 1, 0.01),
                       "shared shell animation completes")
                expect(panel.controlBaseContentFits,
                       "Control content still fits above footer")
                stablePageHeight = panel.openHeight
                stableViewportHeight = panel.sizerItem.height
                controller.showPage(controller.notificationsPage)
                phase = 5
                next(25)
                return
            }

            if (testRoot.phase === 5) {
                expect(near(controller.progress, 1, 0.001)
                       && near(panel.sizerItem.height,
                               stableViewportHeight, 0.001),
                       "page switch never restarts shell geometry")
                expect(panel.controlPageX < 0 && panel.historyPageX > 0,
                       "page cards transition independently")
                expect(!panel.controlPageReady && !panel.historyPageReady,
                       "moving pages reject input")
                phase = 6
                next(220)
                return
            }

            if (testRoot.phase === 6) {
                expect(near(panel.historyPageOpacity, 1, 0.03)
                       && near(panel.controlPageOpacity, 0, 0.03),
                       "History page settles inside unchanged shell")
                expect(near(panel.openHeight, stablePageHeight, 0.001)
                       && panel.historyPageReady,
                       "History keeps shared final height")
                controller.close()
                phase = 7
                next(50)
                return
            }

            if (testRoot.phase === 7) {
                expect(controller.progress > 0 && controller.progress < 1,
                       "close reverses the single shell progress")
                expectGeometry(controller.progress, "closing")
                reverseProgress = controller.progress
                controller.showPage(controller.controlsPage)
                expect(near(controller.progress, reverseProgress, 0.001),
                       "mid-close reopen has no geometry jump")
                phase = 8
                next(240)
                return
            }

            if (testRoot.phase === 8) {
                expect(near(controller.progress, 1, 0.01)
                       && controller.windowVisible,
                       "reversed opening settles normally")
                controller.close()
                phase = 9
                next(270)
                return
            }

            if (testRoot.phase === 9) {
                expect(near(controller.progress, 0, 0.01)
                       && !controller.windowVisible,
                       "close waits one post-frame delay then hides window")
                controller.reducedMotion = true
                controller.showPage(controller.notificationsPage)
                expect(controller.progress === 1
                       && controller.windowVisible,
                       "reduced motion opens immediately")
                expect(panel.historyPageOpacity === 1
                       && panel.historyPageX === 0,
                       "reduced motion switches page immediately")
                controller.close()
                expect(controller.progress === 0
                       && !controller.windowVisible,
                       "reduced motion closes immediately")
                finish()
            }
        }
    }

    Component.onCompleted: {
        phase = 0
        next(0)
    }
}
