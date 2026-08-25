import QtQuick
import Quickshell
import "components"
import "config" as Config

ShellRoot {
    id: testRoot

    property int failureCount: 0
    property int phase: 0

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

        hideDelay: 30
    }

    RightPanelPageSwitcher {
        id: minimumWidthSwitcher

        // 560px 主体扣除左右各 24px 内容边距后的实际页脚宽度。
        width: 560 - Config.BarTuning.rightPanelPaddingH * 2
        visible: false
    }

    Timer {
        id: phaseTimer

        interval: 45
        onTriggered: {
            if (testRoot.phase === 1) {
                testRoot.expect(!controller.windowVisible,
                                "window hidden after close animation")

                controller.togglePage(controller.notificationsPage)
                testRoot.expect(controller.open,
                                "notification entry opens panel")
                testRoot.expect(controller.windowVisible,
                                "notification entry exposes window")
                testRoot.expectEqual(controller.page,
                                     controller.notificationsPage,
                                     "notification entry selects history page")

                controller.showPage(controller.controlsPage)
                testRoot.expect(controller.open,
                                "cross-page switch keeps panel open")
                testRoot.expectEqual(controller.page,
                                     controller.controlsPage,
                                     "cross-page switch selects controls")

                controller.close()
                controller.showPage(controller.notificationsPage)
                testRoot.expect(controller.open,
                                "reopen cancels pending close")
                testRoot.expect(controller.windowVisible,
                                "window remains visible after reopen")

                controller.reducedMotion = true
                controller.close()
                testRoot.expect(!controller.open,
                                "reduced-motion close clears open state")
                testRoot.expect(!controller.windowVisible,
                                "reduced-motion close hides immediately")

                controller.reducedMotion = false
                controller.showPage(99)
                testRoot.expectEqual(controller.page,
                                     controller.controlsPage,
                                     "unknown page normalizes to controls")
                controller.reducedMotion = true
                controller.close()
                testRoot.finish()
            }
        }
    }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            testRoot.expect(!controller.open, "initially closed")
            testRoot.expect(!controller.windowVisible,
                            "initial window hidden")
            testRoot.expectEqual(Config.BarTuning.rightPanelWidthMin,
                                 560, "minimum panel width")
            testRoot.expectEqual(Config.BarTuning.rightPanelWidthMax,
                                 640, "maximum panel width")
            testRoot.expectEqual(Config.BarTuning.rightPanelNeckWidth,
                                 304, "fixed connection neck")
            testRoot.expectEqual(Config.BarTuning.rightPanelFlare,
                                 16, "neck flare")
            testRoot.expectEqual(Config.BarTuning.rightPanelRadius,
                                 18, "panel radius")
            testRoot.expectEqual(Config.BarTuning.rightPanelHeight,
                                 760, "shared page height")
            testRoot.expectEqual(Config.BarTuning.panelPageCardOffset,
                                 28, "page card offset")
            testRoot.expect(
                Math.abs(Config.BarTuning.panelPageCardInactiveScale
                         - 0.985) < 0.0001,
                "page card inactive scale")
            testRoot.expectEqual(Config.BarTuning.panelWidthOpenDelay,
                                 40, "width open delay")
            testRoot.expectEqual(Config.BarTuning.panelHeightOpenDelay,
                                 95, "height open delay")
            testRoot.expectEqual(Config.BarTuning.panelContentInDelay,
                                 180, "content open delay")
            testRoot.expectEqual(Config.BarTuning.panelWidthOpenDuration,
                                 170, "width open duration")
            testRoot.expectEqual(Config.BarTuning.panelHeightOpenDuration,
                                 240, "height open duration")
            testRoot.expectEqual(Config.BarTuning.panelContentInDuration,
                                 150, "content open duration")
            testRoot.expect(minimumWidthSwitcher.tabsWidth <= 280,
                            "tabs stay within half of the minimum panel width")
            testRoot.expectEqual(controller.rightPanelPage,
                                 "control", "public page state starts on control")
            testRoot.expect(!controller.rightPanelOpen,
                            "public open state starts closed")

            controller.togglePage(controller.controlsPage)
            testRoot.expect(controller.open, "controls entry opens panel")
            testRoot.expect(controller.windowVisible,
                            "controls entry exposes window")
            testRoot.expectEqual(controller.page,
                                 controller.controlsPage,
                                 "controls entry selects controls page")

            controller.togglePage(controller.controlsPage)
            testRoot.expect(!controller.open,
                            "same entry closes panel")
            testRoot.expect(controller.windowVisible,
                            "window stays alive during close animation")
            testRoot.expect(controller.closing,
                            "closing state covers delayed hide")

            testRoot.phase = 1
            phaseTimer.start()
        }
    }
}
