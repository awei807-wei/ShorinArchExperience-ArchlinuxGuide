import "."
import QtQuick
import Quickshell
import "config" as Config

ShellRoot {
    id: testRoot

    property int failureCount: 0

    function expect(condition, label) {
        if (condition)
            return ;

        failureCount += 1;
        console.error("[BarLayoutCheck] failed: " + label);
    }

    function expectEqual(actual, expected, label) {
        if (actual === expected)
            return ;

        failureCount += 1;
        console.error("[BarLayoutCheck] " + label + ": expected=" + expected + " actual=" + actual);
    }

    function expectNoOverlap(target, label) {
        expect(target.contextRight + target.islandGap <= target.clockLeft,
               label + " context/clock overlap: " + target.contextRight + " + " + target.islandGap + " > " + target.clockLeft);
        expect(target.clockRight + target.islandGap <= target.systemLeft,
               label + " clock/system overlap: " + target.clockRight + " + " + target.islandGap + " > " + target.systemLeft);
    }

    function expectedLayoutMode(targetWidth) {
        if (targetWidth >= Config.BarTuning.fullTrayMinWidth)
            return 0;

        if (targetWidth >= Config.BarTuning.traySurfaceMinWidth)
            return 2;

        if (targetWidth >= Config.BarTuning.compactMinWidth)
            return 3;

        return 4;
    }

    function expectedContextWidth(mode) {
        return mode >= 4 ? Config.BarTuning.contextUltraWidth : (mode >= 3 ? Config.BarTuning.contextCompactWidth : Config.BarTuning.contextWidth);
    }

    function expectedClockWidth(mode) {
        if (mode >= 4)
            return Config.BarTuning.clockUltraWidth;

        if (mode >= 3)
            return Config.BarTuning.clockCompactWidth;

        return Config.BarTuning.clockWidth;
    }

    function expectedMetricsWidth(mode) {
        return Config.BarTuning.rightIslandMetricsWidth;
    }

    function expectedSystemWidth(target, mode) {
        return expectedMetricsWidth(mode) + Config.BarTuning.metricsUtilityGap
            + target.trayWidth + Config.BarTuning.trayPowerGap
            + Config.BarTuning.powerIslandWidth;
    }

    function checkBar(target, label) {
        const mode = expectedLayoutMode(target.width);
        expectEqual(target.layoutMode, mode, label + " layout mode");
        expectEqual(target.islandHeight, Config.BarTuning.islandHeight, label + " island height");
        expectEqual(target.barHeight, Config.BarTuning.barHeight, label + " bar height");
        expectEqual(target.height, Config.BarTuning.barHeight, label + " rendered bar height");
        expectEqual(target.topBorderWidth, Config.BarTuning.barTopBorderWidth, label + " top border width");
        expectEqual(target.notchRadius, Config.BarTuning.barNotchRadius, label + " notch radius");
        expectEqual(target.exclusionGap, Config.BarTuning.barExclusionGap, label + " exclusion gap");
        expectEqual(target.islandContentTop, Config.BarTuning.islandContentTop, label + " content top");
        expectEqual(target.actualTrayIconLimit,
                    Math.min(target.trayDirectIconLimit,
                             Config.BarTuning.rightIslandDirectIconLimit),
                    label + " direct tray icon limit");
        expectEqual(target.trayVisible, true, label + " tray visibility");
        expectEqual(target.metricDetailsVisible, false,
                    label + " metric detail visibility");
        expectEqual(target.contextWidth, expectedContextWidth(mode), label + " context width");
        expectEqual(target.clockWidth, expectedClockWidth(mode), label + " clock width");
        expectEqual(target.metricsWidth, expectedMetricsWidth(mode), label + " metrics width");
        expectEqual(target.systemWidth, expectedSystemWidth(target, mode), label + " system width");
        expect(target.trayWidth >= Config.BarTuning.trayMinimumWidth,
               label + " dynamic tray minimum width");
        expect(target.systemWidth >= 218 && target.systemWidth <= 240,
               label + " closed right island width budget");
        expectEqual(target.systemSpacing, Config.BarTuning.metricsUtilityGap, label + " metrics/utility gap");
        expectEqual(target.utilitySpacing, Config.BarTuning.trayPowerGap, label + " tray/power gap");
        expectEqual(target.contextContourLeft, 0,
                    label + " left contour flush edge");
        expectEqual(target.contextContourRight,
                    target.contextRight + target.notchRadius,
                    label + " left contour right flare");
        expectEqual(target.clockContourLeft,
                    target.clockLeft - target.notchRadius,
                    label + " clock contour left flare");
        expectEqual(target.clockContourRight,
                    target.clockRight + target.notchRadius,
                    label + " clock contour right flare");
        expectEqual(target.systemContourLeft,
                    target.systemLeft - target.notchRadius,
                    label + " system contour left flare");
        expectEqual(target.systemContourRight,
                    target.width,
                    label + " system contour flush edge");
        expect(target.contextContourRight <= target.clockContourLeft,
               label + " left/center contour overlap: "
               + target.contextContourRight + " > " + target.clockContourLeft);
        expect(target.clockContourRight <= target.systemContourLeft,
               label + " center/right contour overlap: "
               + target.clockContourRight + " > " + target.systemContourLeft);
        expect(target.contextRight + target.exclusionGap <= target.clockLeft,
               label + " left/center exclusion gap");
        expect(target.clockRight + target.exclusionGap <= target.systemLeft,
               label + " center/right exclusion gap");
        expectNoOverlap(target, label);
    }

    function runChecks() {
        expect(Config.BarTuning.fullTrayMinWidth > Config.BarTuning.traySurfaceMinWidth, "full-tray threshold must exceed tray-surface threshold");
        expect(Config.BarTuning.traySurfaceMinWidth > Config.BarTuning.compactMinWidth, "tray-surface threshold must exceed compact threshold");
        expect(Config.BarTuning.compactMinWidth > Config.BarTuning.minimumSupportedWidth, "compact threshold must exceed minimum supported width");
        expect(Config.BarTuning.trayIconSize <= Config.BarTuning.trayItemWidth, "tray icon must fit inside its slot");
        expectEqual(Config.BarTuning.barMarginTop, 0, "bar touches screen top");
        expectEqual(Config.BarTuning.barMarginSide, 0, "bar touches both screen sides");
        expect(Config.BarTuning.barTopBorderWidth > 0,
               "top border must remain visible");
        expect(Config.BarTuning.barTopBorderWidth + 2 * Config.BarTuning.barNotchRadius
               <= Config.BarTuning.barHeight,
               "paired notch radii must fit inside bar height");
        expect(Config.BarTuning.barNotchRadius > 0,
               "reverse contour must have a positive radius");
        expectEqual(Config.BarTuning.screenEdgeBorderWidth,
                    Config.BarTuning.barTopBorderWidth,
                    "screen edge rail matches top strip");
        expect(Config.BarTuning.screenEdgeCornerRadius > 0,
               "screen edge melt must have a positive radius");
        expect(Config.BarTuning.barExclusionGap >= 2 * Config.BarTuning.barNotchRadius,
               "exclusion gap must contain both reverse corners");
        expect(Config.BarTuning.islandContentTop + Config.BarTuning.islandHeight
               <= Config.BarTuning.barHeight,
               "island content must fit inside bar window");
        checkBar(wide, "2048");
        checkBar(standard, "1280");
        checkBar(compact, "1024");
        checkBar(narrow, "800");
        checkBar(ultra, "minimum");
        checkBar(modeTwoEdge, "tray threshold");
        checkBar(modeThreeEdge, "below tray threshold");
        expectEqual(neckOpen.animatedRightContourWidth,
                    Config.BarTuning.rightPanelNeckWidth,
                    "open right island uses fixed neck width");
        expect(neckOpen.systemWidth <= neckOpen.animatedRightContourWidth,
               "right island content fits inside open neck");
        expect(neckOpen.animatedRightContourWidth
               / Config.BarTuning.rightPanelWidthMax >= 0.46,
               "open neck occupies at least 46% of maximum panel");
        expect(neckOpen.animatedRightContourWidth
               / Config.BarTuning.rightPanelWidthMax <= 0.50,
               "open neck occupies at most 50% of maximum panel");
        expectEqual(modeTwoEdge.layoutMode, 2, "configured tray threshold mode");
        expectEqual(modeThreeEdge.layoutMode, 3, "configured below-tray mode");
        if (failureCount === 0) {
            console.log("[BarLayoutCheck] PASS");
            Qt.exit(0);
        } else {
            console.error("[BarLayoutCheck] FAIL count=" + failureCount);
            Qt.exit(1);
        }
    }

    Item {
        width: 2048
        height: (Config.BarTuning.barHeight + 4) * 8

        Bar {
            id: wide

            width: 2048
            height: Config.BarTuning.barHeight
            trayDirectIconLimit: 3
            notificationHistoryCount: 1
        }

        Bar {
            id: standard

            width: 1280
            height: Config.BarTuning.barHeight
            y: Config.BarTuning.barHeight + 4
            trayDirectIconLimit: 3
            notificationHistoryCount: 1
        }

        Bar {
            id: compact

            width: 1024
            height: Config.BarTuning.barHeight
            y: (Config.BarTuning.barHeight + 4) * 2
            trayDirectIconLimit: 3
            notificationHistoryCount: 1
        }

        Bar {
            id: narrow

            width: 800
            height: Config.BarTuning.barHeight
            y: (Config.BarTuning.barHeight + 4) * 3
            trayDirectIconLimit: 3
            notificationHistoryCount: 1
        }

        Bar {
            id: ultra

            width: Config.BarTuning.minimumSupportedWidth
            height: Config.BarTuning.barHeight
            y: (Config.BarTuning.barHeight + 4) * 4
            trayDirectIconLimit: 3
            notificationHistoryCount: 1
        }

        Bar {
            id: modeTwoEdge

            width: Config.BarTuning.traySurfaceMinWidth
            height: Config.BarTuning.barHeight
            y: (Config.BarTuning.barHeight + 4) * 5
            trayDirectIconLimit: 3
            notificationHistoryCount: 1
        }

        Bar {
            id: modeThreeEdge

            width: Config.BarTuning.traySurfaceMinWidth - 1
            height: Config.BarTuning.barHeight
            y: (Config.BarTuning.barHeight + 4) * 6
            trayDirectIconLimit: 3
            notificationHistoryCount: 1
        }

        Bar {
            id: neckOpen

            width: 2048
            height: Config.BarTuning.barHeight
            y: (Config.BarTuning.barHeight + 4) * 7
            trayDirectIconLimit: 3
            notificationHistoryCount: 1
            rightPanelOpen: true
            panelNeckReducedMotion: true
        }

    }

    Timer {
        interval: 0
        running: true
        onTriggered: Qt.callLater(testRoot.runChecks)
    }

}
