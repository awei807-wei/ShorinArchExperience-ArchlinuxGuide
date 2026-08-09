import QtQuick
import Quickshell

// 无窗口布局检查：覆盖 1280 / 1600 / 2048，并验证三舱边界不重叠。
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
        const margin = Math.max(14, width * 0.014)
        const leftWidth = Math.max(210, Math.min(390, width * 0.235))
        const centerWidth = Math.max(220, Math.min(340, width * 0.22))
        const rightWidth = width < 1000
                         ? Math.max(288, Math.min(360, width * 0.28))
                         : Math.max(390, Math.min(500, width * 0.31))
        const leftEnd = margin + leftWidth
        const rightStart = width - margin - rightWidth
        const centerX = Math.max(leftEnd + 12,
                                 Math.min((width - centerWidth) / 2,
                                          rightStart - centerWidth - 12))

        expect(leftEnd + 10 <= centerX, width + " left/center contour gap")
        expect(centerX + centerWidth + 10 <= rightStart, width + " center/right contour gap")
        expect(rightStart + rightWidth <= width, width + " right pod ends inside viewport")

        // The right cluster is three independent contours with narrow transparent gaps.
        const compact = width < 1120
        const narrow = width < 1000
        const balanced = width < 1500
        const podGap = narrow ? 5 : (compact ? 7 : 8)
        const trayWidth = narrow ? 102 : (compact ? 112 : (balanced ? 122 : 132))
        const powerWidth = narrow ? 44 : (compact ? 48 : (balanced ? 52 : 56))
        const metricsWidth = rightWidth - trayWidth - powerWidth - 2 * podGap
        expect(metricsWidth > 0, width + " right metrics contour has positive width")

        const metricsInset = narrow ? 2 : (compact ? 4 : (balanced ? 4 : 6))
        const metricsContentWidth = metricsWidth - 2 * (metricsInset + 8)
        const metricCount = narrow ? 3 : 4
        const metricWidth = narrow ? 30 : (compact ? 36 : (balanced ? 38 : 46))
        const metricGap = narrow ? 5 : (compact ? 7 : (balanced ? 8 : 10))
        const metricNeed = metricCount * metricWidth + (metricCount - 1) * metricGap
        expect(metricNeed <= metricsContentWidth,
               width + " metrics contour overflow: need=" + metricNeed
               + " available=" + metricsContentWidth)

        const trayInset = narrow ? 2 : (compact ? 4 : (balanced ? 4 : 6))
        const trayContentWidth = trayWidth - 2 * (trayInset + 8)
        const utilityNeed = 3 * (narrow ? 23 : (compact ? 25 : (balanced ? 27 : 29)))
            + 2 * (narrow ? 5 : 7)
        expect(utilityNeed <= trayContentWidth,
               width + " tray contour overflow: need=" + utilityNeed
               + " available=" + trayContentWidth)

        const powerContentWidth = powerWidth - 16 // power contour uses sideInset 0
        const powerNeed = narrow ? 18 : 20
        expect(powerNeed <= powerContentWidth,
               width + " power contour overflow: need=" + powerNeed
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
