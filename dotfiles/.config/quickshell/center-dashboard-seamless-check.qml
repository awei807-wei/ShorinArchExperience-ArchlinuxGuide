import QtQuick
import Quickshell
import "components"
import "config" as Config

ShellRoot {
    id: root

    property int failureCount: 0

    function expect(condition, message) {
        if (!condition) {
            failureCount++
            console.error("[SeamlessCheck] FAILED: " + message)
        }
    }

    CenterPanelController {
        id: controller
        animationDuration: 10
    }

    BarContour {
        id: contour
        width: 1920
        height: 740
        notchHeight: 40
        notchRadius: 15
        topBorderWidth: 6
        centerWidth: 240 + (900 - 240) * controller.centerPanelProgress
        centerBottomY: 40 + 700 * controller.centerPanelProgress
        centerBottomRadius: 15 + (17 - 15) * controller.centerPanelProgress
    }

    ClockIsland {
        id: clock
        panelProgress: controller.centerPanelProgress
        panelOpen: controller.open
    }

    Timer {
        interval: 50
        running: true
        repeat: false
        onTriggered: {
            // 1. 验证收拢状态 (p = 0)
            expect(controller.centerPanelProgress === 0, "initial progress is 0")
            expect(contour.safeCenterBottomRadius === 15, "closed safe bottom radius is 15")
            expect(contour.outlinePath.indexOf("M 0 40") === 0, "outlinePath starts at M 0 40")
            expect(clock.fadeProgress === 0, "clock fadeProgress is 0 when closed")

            // 2. 触发打开
            controller.togglePage("home")
            expect(controller.open, "controller opened")

            // 3. 验证展开动力学
            Timer {
                interval: 40
                running: true
                repeat: false
                onTriggered: {
                    expect(controller.centerPanelProgress > 0.9, "progress reached open state")
                    expect(contour.centerBottomY > 600, "centerBottomY expanded downwards")
                    expect(contour.safeCenterBottomRadius >= 15 && contour.safeCenterBottomRadius <= 17, "safe radius clamped within [15, 17]")
                    expect(clock.fadeProgress === 1, "clock fully faded out in open state")

                    // 4. 收拢
                    controller.close()
                    expect(!controller.open, "closed successfully")

                    if (failureCount === 0) {
                        console.log("[SeamlessCheck] ALL SEAMLESS INTEGRATION CHECKS PASSED!")
                    } else {
                        console.error("[SeamlessCheck] " + failureCount + " CHECKS FAILED!")
                    }
                    Qt.quit()
                }
            }
        }
    }
}