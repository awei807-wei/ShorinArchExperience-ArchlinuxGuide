import QtQuick
import Quickshell
import "components"
import "config" as Config
import "." as Root

ShellRoot {
    id: root

    property int failureCount: 0

    function expect(cond, msg) {
        if (!cond) {
            failureCount++
            console.error("[PrewarmMotionCheck] FAILED: " + msg)
        }
    }

    PowerMenuController {
        id: powerController
        animationDuration: 10
    }

    CenterPanelController {
        id: centerController
        animationDuration: 10
    }

    RightPanelController {
        id: rightController
        animationDuration: 10
    }

    Timer {
        interval: 30
        running: true
        repeat: false
        onTriggered: {
            // 1. 验证 PrewarmService 契约
            expect(Root.PrewarmService.opacityFloor === 0.001, "opacityFloor is 0.001")
            expect(Root.PrewarmService.duration === Config.BarTuning.panelPrewarmDuration, "duration matches tuning")

            // 2. 验证 Anim 物理曲线映射
            Config.Anim.curveStyle = "spring"
            expect(Config.Anim.globalCurve === Easing.OutBack, "spring curve maps to OutBack")
            expect(Config.Anim.globalOvershoot === 1.10, "spring overshoot tuned to 1.10")

            Config.Anim.curveStyle = "smooth"
            expect(Config.Anim.globalCurve === Easing.OutCubic, "smooth curve maps to OutCubic")

            Config.Anim.curveStyle = "snappy"
            expect(Config.Anim.globalCurve === Easing.OutQuad, "snappy curve maps to OutQuad")

            // 恢复 smooth
            Config.Anim.curveStyle = "smooth"

            // 3. 验证速度缩放
            Config.Anim.speedMultiplier = 2.0
            expect(Config.Anim.fast < 100, "fast duration scaled faster")
            Config.Anim.speedMultiplier = 1.0

            // 4. 验证控制器在 spring 模式下的曲线协同
            powerController.toggle()
            expect(powerController.open, "powerController open")

            centerController.togglePage("home")
            expect(centerController.open, "centerController open")

            rightController.showPage(0)
            expect(rightController.open, "rightController open")

            // 5. 验证预热手动完成信号
            Root.PrewarmService.complete()
            expect(!Root.PrewarmService.active, "prewarming inactive after complete()")

            if (failureCount === 0) {
                console.log("[PrewarmMotionCheck] ALL GLOBAL PREWARM & MOTION CHECKS PASSED!")
            } else {
                console.error("[PrewarmMotionCheck] " + failureCount + " CHECKS FAILED!")
            }
            Qt.quit()
        }
    }
}