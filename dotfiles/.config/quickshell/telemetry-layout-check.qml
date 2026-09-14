import QtQuick
import Quickshell
import "components" as Components
import "config" as Config

ShellRoot {
    id: testRoot

    property int failureCount: 0

    function expect(condition, label) {
        if (condition)
            return

        failureCount += 1
        console.error("[TelemetryLayoutCheck] failed: " + label)
    }

    function finish() {
        expect(metrics.metricCount === 3, "exactly three metric cells")
        expect(metrics.cpuValue === "28%", "CPU value is formatted")
        expect(metrics.memoryValue === "62%", "RAM value is formatted")
        expect(metrics.batteryValue === "100%", "missing battery falls back to 100%")
        expect(metrics.batteryValueColor === metrics.batteryFallbackColor,
               "missing battery uses healthy green")
        expect(metrics.renderedMetricContentWidth <= metrics.metricCellWidth,
               "worst-case value fits one equal-width cell")
        expect(metrics.metricCellWidth - metrics.renderedMetricContentWidth >= 1,
               "worst-case value keeps at least 1px layout headroom")
        expect(metrics.metricCellWidth * 1.5 === Math.round(metrics.metricCellWidth * 1.5),
               "metric cell lands on whole physical pixels at 1.5x")
        expect(Config.BarTuning.metricsHorizontalPadding * 1.5
               === Math.round(Config.BarTuning.metricsHorizontalPadding * 1.5),
               "telemetry padding lands on whole physical pixels at 1.5x")
        expect(Config.BarTuning.metricsSeparatorWidth === 10,
               "separator uses the maximum compact spacing slot")
        expect(metrics.minimumSeparatorClearance >= 3,
               "values keep at least 3px visual clearance from slash glyphs")
        expect(metrics.monoFont === "Consolas",
               "telemetry uses the compact screen-optimized monospace")
        expect(metrics.width === Config.BarTuning.rightIslandMetricsWidth,
               "telemetry uses the configured fixed width")
        expect(Config.BarTuning.rightIslandMetricsWidth === 164,
               "telemetry receives the reallocated 164px budget")

        metrics.batteryAvailable = true
        metrics.batteryPercent = 42
        Qt.callLater(function() {
            testRoot.expect(metrics.batteryValue === "42%",
                            "available battery exposes measured percentage")
            testRoot.expect(metrics.batteryValueColor === metrics.valueColor,
                            "available battery uses the high-contrast value color")
            if (testRoot.failureCount === 0)
                console.log("[TelemetryLayoutCheck] PASS")
            else
                console.error("[TelemetryLayoutCheck] FAIL count=" + testRoot.failureCount)
            Qt.exit(testRoot.failureCount === 0 ? 0 : 1)
        })
    }

    Components.Metrics {
        id: metrics

        width: Config.BarTuning.rightIslandMetricsWidth
        height: Config.BarTuning.islandHeight
        cpuPercent: 28
        memoryPercent: 62
        batteryAvailable: false
    }

    Component.onCompleted: Qt.callLater(testRoot.finish)
}
