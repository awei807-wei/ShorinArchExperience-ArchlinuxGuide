import QtQuick
import Quickshell

// 无窗口布局检查：覆盖 2048 / 1600 / 1280 / 800，并验证 rail-attached 岛体边界。
ShellRoot {
    id: checkRoot
    property int failures: 0

    function expect(condition, message) {
        if (condition)
            return
        failures += 1
        console.error("[EdgeIntegratedLayoutCheck] " + message)
    }

    function checkWidth(width) {
        const joinRadius = width < 1000 ? 18 : 20
        const leftWidth = Math.max(210, Math.min(390, width * 0.235))
        const centerWidth = width < 1000
                          ? 200
                          : Math.max(220, Math.min(340, width * 0.22))
        const rightWidth = width < 1000
                         ? Math.max(288, Math.min(360, width * 0.28))
                         : Math.max(390, Math.min(500, width * 0.31))
        const leftEnd = leftWidth
        const rightStart = width - rightWidth
        const centerX = Math.max(leftEnd + 12,
                                 Math.min((width - centerWidth) / 2,
                                         rightStart - centerWidth - 12))

        expect(leftEnd + 10 <= centerX, width + " left/center contour gap")
        expect(centerX + centerWidth + 10 <= rightStart,
               width + " center/right island body gap")
        expect(leftWidth + joinRadius <= width,
               width + " left rail-attached item stays inside viewport")
        expect(centerX - joinRadius >= 0,
               width + " center rail-attached item stays inside viewport")
        expect(rightStart - joinRadius >= 0,
               width + " right rail-attached item stays inside viewport")
        expect(rightStart + rightWidth === width,
               width + " right island body flushes to viewport edge")
        expect(joinRadius >= 18 && joinRadius <= 22,
               width + " quarter-circle join radius")

        // The right cluster is one contour; these values describe only its
        // internal regions and separators, not separate outer pods.
        const compact = width < 1120
        const narrow = width < 1000
        const balanced = width < 1500
        const groupGap = narrow ? 5 : (compact ? 7 : 8)
        const trayWidth = narrow ? 102 : (compact ? 112 : (balanced ? 122 : 132))
        const powerWidth = narrow ? 44 : (compact ? 48 : (balanced ? 52 : 56))
        const outerInset = narrow ? 2 : (compact ? 4 : (balanced ? 4 : 6))
        const trayInset = narrow ? 2 : (compact ? 4 : (balanced ? 4 : 6))
        const contentWidth = rightWidth - 2 * (outerInset + 8)
        const trayContentWidth = Math.max(
            trayWidth - 2 * (trayInset + 8),
            3 * (narrow ? 23 : (compact ? 25 : (balanced ? 27 : 29)))
            + 2 * (narrow ? 5 : 7))
        const powerContentWidth = Math.max(powerWidth - 16, narrow ? 18 : 20)
        const metricsContentWidth = contentWidth - trayContentWidth
                                 - powerContentWidth - 2 * groupGap
        expect(metricsContentWidth > 0, width + " unified metrics region has positive width")
        const metricCount = narrow ? 3 : 4
        const metricWidth = narrow ? 30 : (compact ? 36 : (balanced ? 38 : 46))
        const metricGap = narrow ? 5 : (compact ? 7 : (balanced ? 8 : 10))
        const metricNeed = metricCount * metricWidth + (metricCount - 1) * metricGap
        expect(metricNeed <= metricsContentWidth,
               width + " unified metrics region overflow: need=" + metricNeed
               + " available=" + metricsContentWidth)

        const utilityNeed = 3 * (narrow ? 23 : (compact ? 25 : (balanced ? 27 : 29)))
            + 2 * (narrow ? 5 : 7)
        expect(utilityNeed <= trayContentWidth,
               width + " unified tray region overflow: need=" + utilityNeed
               + " available=" + trayContentWidth)

        const powerNeed = narrow ? 18 : 20
        expect(powerNeed <= powerContentWidth,
               width + " unified power region overflow: need=" + powerNeed
               + " available=" + powerContentWidth)
    }

    Item {
        id: harness
        width: 2048
        height: 3 * 112

        Component.onCompleted: {
            checkWidth(2048)
            checkWidth(1600)
            checkWidth(1280)
            checkWidth(800)
            if (failures === 0) {
                console.log("[EdgeIntegratedLayoutCheck] PASS")
                // The wrapper terminates the child after seeing PASS.  Qt.exit
                // keeps the intended status explicit for QML hosts that wire
                // QQmlEngine::exit to the application event loop.
                Qt.exit(0)
            } else {
                console.error("[EdgeIntegratedLayoutCheck] FAIL count=" + failures)
                Qt.exit(1)
            }
        }
    }
}
