import QtQuick
import Quickshell
import "components"
import "config" as Config

ShellRoot {
    id: testRoot

    property int failureCount: 0
    property int phase: 0
    property real openingProgress: 0
    property real closingProgress: 0

    QtObject { id: screenA }
    QtObject { id: screenB }

    function expect(condition, label) {
        if (condition)
            return

        failureCount += 1
        console.error("[RightPanelStateCheck] failed: " + label)
    }

    function expectEqual(actual, expected, label) {
        if (actual === expected)
            return

        failureCount += 1
        console.error("[RightPanelStateCheck] " + label
                      + ": expected=" + expected + " actual=" + actual)
    }

    function next(delay) {
        phaseTimer.interval = delay
        phaseTimer.restart()
    }

    function finish() {
        if (failureCount === 0) {
            console.log("[RightPanelStateCheck] PASS")
            Qt.exit(0)
        } else {
            console.error("[RightPanelStateCheck] FAIL count=" + failureCount)
            Qt.exit(1)
        }
    }

    RightPanelController {
        id: controller

        animationDuration: 80
        hideDelay: 10
    }

    RightPanelPageSwitcher {
        id: minimumWidthSwitcher

        // 560px 主体扣除左右各 24px 内容边距后的实际页脚宽度。
        width: 560 - Config.BarTuning.rightPanelPaddingH * 2
        visible: false
    }

    Timer {
        id: phaseTimer

        onTriggered: {
            if (phase === 0) {
                expect(!controller.open, "initially closed")
                expect(!controller.windowVisible, "initial window hidden")
                expectEqual(Config.BarTuning.rightPanelWidthMin,
                            560, "minimum panel width")
                expectEqual(Config.BarTuning.rightPanelWidthMax,
                            640, "maximum panel width")
                expectEqual(Config.BarTuning.rightPanelNeckWidth,
                            304, "fixed connection neck")
                expectEqual(Config.BarTuning.rightPanelFlare,
                            16, "neck flare")
                expectEqual(Config.BarTuning.rightPanelRadius,
                            18, "panel radius")
                expectEqual(Config.BarTuning.rightPanelHeight,
                            760, "shared page height")
                expectEqual(Config.BarTuning.panelPageCardOffset,
                            28, "page card offset")
                expect(Math.abs(
                    Config.BarTuning.panelPageCardInactiveScale - 0.985)
                    < 0.0001, "page card inactive scale")
                expectEqual(Config.BarTuning.panelShellDuration,
                            300, "shared shell duration")
                expectEqual(Config.BarTuning.panelWindowHideDelay,
                            20, "post-frame window hide delay")
                expect(Math.abs(
                    Config.BarTuning.panelBodyStartProgress - 0.10)
                    < 0.0001, "body reveal threshold")
                expect(Math.abs(
                    Config.BarTuning.panelContentStartProgress - 0.52)
                    < 0.0001, "content reveal threshold")
                expectEqual(Config.BarTuning.panelSafeRevealExtra,
                            2, "safe reveal overshoot")
                expect(minimumWidthSwitcher.tabsWidth <= 280,
                       "tabs stay within half of minimum panel width")
                expectEqual(controller.rightPanelPage,
                            "control", "public page starts on control")
                expect(!controller.rightPanelOpen,
                       "public open state starts closed")
                expect(controller.rightPanelProgress === 0,
                       "shared shell progress starts collapsed")

                controller.togglePage(
                    controller.controlsPage, 240, 304, screenA
                )
                expect(controller.open, "controls entry opens panel")
                expect(controller.windowVisible,
                       "opening exposes window before animation")
                expectEqual(controller.page, controller.controlsPage,
                            "controls entry selects controls page")
                expectEqual(controller.baseRightWidth, 240,
                            "opening captures the Bar base width")
                expectEqual(controller.targetRightWidth, 304,
                            "opening captures the Bar target width")
                expect(controller.isScreenActive(screenA)
                       && !controller.isScreenActive(screenB),
                       "only the source screen becomes active")
                phase = 1
                next(25)
                return
            }

            if (phase === 1) {
                openingProgress = controller.progress
                expect(openingProgress > 0 && openingProgress < 1,
                       "shared progress animates toward open")
                controller.togglePage(
                    controller.controlsPage, 240, 304, screenA
                )
                expect(!controller.open, "same entry starts close")
                expect(controller.windowVisible,
                       "window stays alive during close")
                expect(controller.closing,
                       "closing state covers animation and hide delay")
                expect(Math.abs(controller.progress - openingProgress) < 0.001,
                       "direction reversal starts from current progress")
                phase = 2
                next(30)
                return
            }

            if (phase === 2) {
                expect(controller.progress < openingProgress,
                       "close moves the same progress backward")
                expect(controller.windowVisible,
                       "window remains visible before close completion")
                phase = 3
                next(100)
                return
            }

            if (phase === 3) {
                expect(controller.progress === 0,
                       "close settles at zero")
                expect(!controller.windowVisible,
                       "window hides after post-frame delay")
                controller.togglePage(
                    controller.notificationsPage, 218, 278, screenA
                )
                expect(controller.open,
                       "notification entry opens panel")
                expect(controller.windowVisible,
                       "notification entry exposes window")
                expectEqual(controller.page,
                            controller.notificationsPage,
                            "notification entry selects History")
                expectEqual(controller.baseRightWidth, 218,
                            "new opening refreshes the Bar base width")
                expectEqual(controller.targetRightWidth, 278,
                            "constrained screen supplies its own target width")
                phase = 4
                next(95)
                return
            }

            if (phase === 4) {
                expect(Math.abs(controller.progress - 1) < 0.001,
                       "opening settles at one")
                controller.showPage(controller.controlsPage)
                expect(controller.open && controller.progress === 1,
                       "cross-page switch leaves shell settled")
                expectEqual(controller.page, controller.controlsPage,
                            "cross-page switch selects Control")
                controller.close()
                phase = 5
                next(25)
                return
            }

            if (phase === 5) {
                closingProgress = controller.progress
                expect(closingProgress > 0 && closingProgress < 1,
                       "settled panel begins shared close")
                controller.showPage(controller.notificationsPage)
                expect(controller.open && controller.windowVisible,
                       "mid-close reopen keeps window alive")
                expect(Math.abs(controller.progress - closingProgress) < 0.001,
                       "mid-close reopen does not jump")
                phase = 6
                next(95)
                return
            }

            if (phase === 6) {
                expect(Math.abs(controller.progress - 1) < 0.001,
                       "reopened shell returns to one")
                expectEqual(controller.page,
                            controller.notificationsPage,
                            "reopen keeps requested page")

                controller.close()
                phase = 7
                next(25)
                return
            }

            if (phase === 7) {
                expect(controller.progress > 0 && controller.progress < 1,
                       "cross-screen case starts during close")
                controller.togglePage(
                    controller.notificationsPage, 230, 304, screenB
                )
                expect(controller.open && controller.windowVisible,
                       "another screen retargets instead of finishing close")
                expect(controller.progress === 0,
                       "closing cross-screen retarget restarts from zero")
                expect(controller.isScreenActive(screenB)
                       && !controller.isScreenActive(screenA),
                       "retarget deactivates the previous screen")
                expectEqual(controller.baseRightWidth, 230,
                            "retarget captures the new screen base width")
                expectEqual(controller.targetRightWidth, 304,
                            "retarget captures the new screen target width")
                phase = 8
                next(95)
                return
            }

            if (phase === 8) {
                expect(Math.abs(controller.progress - 1) < 0.001,
                       "retargeted screen completes its own reveal")

                controller.reducedMotion = true
                controller.close()
                expect(!controller.open
                       && controller.progress === 0
                       && !controller.windowVisible,
                       "reduced-motion close is immediate")

                controller.reducedMotion = false
                controller.showPage(99)
                expectEqual(controller.page, controller.controlsPage,
                            "unknown page normalizes to Control")
                controller.reducedMotion = true
                controller.close()
                finish()
            }
        }
    }

    Component.onCompleted: {
        phase = 0
        next(0)
    }
}
