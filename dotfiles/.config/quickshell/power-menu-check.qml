import QtQuick
import Quickshell
import "components"
import "config" as Config

ShellRoot {
    id: root

    property int failureCount: 0

    function expect(cond, msg) {
        if (!cond) {
            failureCount++
            console.error("[PowerMenuCheck] FAILED: " + msg)
        }
    }

    PowerMenuController {
        id: controller
        animationDuration: 10
    }

    RightSideNotchShape {
        id: shape
        width: 250
        height: 320
        depth: 220
        bodyHeight: 270
    }

    RightPowerMenuContent {
        id: content
        width: 200
        height: 250
    }

    Timer {
        interval: 50
        running: true
        repeat: false
        onTriggered: {
            // 初始状态
            expect(!controller.open, "initial open is false")
            expect(controller.powerMenuProgress === 0, "initial progress is 0")

            // 打开
            controller.toggle()
            expect(controller.open, "open after toggle")
            expect(controller.windowVisible, "windowVisible after open")

            // 形状路径
            expect(shape.shapePathSvg.length > 20, "SVG path generated")
            expect(shape.shapePathSvg.indexOf("M") === 0, "SVG starts with M")

            // 动作列表
            expect(content.actions.length === 5, "5 power actions present")

            // 关闭
            controller.close()
            expect(!controller.open, "closed after close()")

            if (failureCount === 0) {
                console.log("[PowerMenuCheck] ALL CHECKS PASSED!")
            } else {
                console.error("[PowerMenuCheck] " + failureCount + " CHECKS FAILED!")
            }
            Qt.quit()
        }
    }
}