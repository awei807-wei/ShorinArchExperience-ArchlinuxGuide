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
        return mode >= 4 ? Config.BarTuning.metricsUltraWidth : (mode >= 3 ? Config.BarTuning.metricsCompactWidth : Config.BarTuning.metricsWidth);
    }

    function expectedSystemWidth(mode) {
        if (mode <= 1)
            return Config.BarTuning.systemWideWidth;

        if (mode === 2)
            return Config.BarTuning.systemCollapsedTrayWidth;

        if (mode === 3)
            return Config.BarTuning.systemCompactWidth;

        return Config.BarTuning.systemUltraWidth;
    }

    function checkBar(target, label) {
        const mode = expectedLayoutMode(target.width);
        expectEqual(target.layoutMode, mode, label + " layout mode");
        expectEqual(target.islandHeight, Config.BarTuning.islandHeight, label + " island height");
        expectEqual(target.actualTrayIconLimit, mode <= 1 ? target.trayDirectIconLimit : 0, label + " direct tray icon limit");
        expectEqual(target.trayVisible, mode < 3, label + " tray visibility");
        expectEqual(target.metricDetailsVisible, mode < 3, label + " metric detail visibility");
        expectEqual(target.contextWidth, expectedContextWidth(mode), label + " context width");
        expectEqual(target.clockWidth, expectedClockWidth(mode), label + " clock width");
        expectEqual(target.metricsWidth, expectedMetricsWidth(mode), label + " metrics width");
        expectEqual(target.systemWidth, expectedSystemWidth(mode), label + " system width");
        expectEqual(target.systemSpacing, Config.BarTuning.metricsUtilityGap, label + " metrics/utility gap");
        expectEqual(target.utilitySpacing, Config.BarTuning.trayPowerGap, label + " tray/power gap");
        expectNoOverlap(target, label);
    }

    function runChecks() {
        expect(Config.BarTuning.fullTrayMinWidth > Config.BarTuning.traySurfaceMinWidth, "full-tray threshold must exceed tray-surface threshold");
        expect(Config.BarTuning.traySurfaceMinWidth > Config.BarTuning.compactMinWidth, "tray-surface threshold must exceed compact threshold");
        expect(Config.BarTuning.compactMinWidth > Config.BarTuning.minimumSupportedWidth, "compact threshold must exceed minimum supported width");
        expect(Config.BarTuning.trayIconSize <= Config.BarTuning.trayItemWidth, "tray icon must fit inside its slot");
        checkBar(wide, "2048");
        checkBar(standard, "1280");
        checkBar(compact, "1024");
        checkBar(narrow, "800");
        checkBar(ultra, "minimum");
        checkBar(modeTwoEdge, "tray threshold");
        checkBar(modeThreeEdge, "below tray threshold");
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
        height: (Config.BarTuning.islandHeight + 4) * 7

        Bar {
            id: wide

            width: 2048
            height: Config.BarTuning.islandHeight
            trayDirectIconLimit: 3
            notificationHistoryCount: 1
        }

        Bar {
            id: standard

            width: 1280
            height: Config.BarTuning.islandHeight
            y: Config.BarTuning.islandHeight + 4
            trayDirectIconLimit: 3
            notificationHistoryCount: 1
        }

        Bar {
            id: compact

            width: 1024
            height: Config.BarTuning.islandHeight
            y: (Config.BarTuning.islandHeight + 4) * 2
            trayDirectIconLimit: 3
            notificationHistoryCount: 1
        }

        Bar {
            id: narrow

            width: 800
            height: Config.BarTuning.islandHeight
            y: (Config.BarTuning.islandHeight + 4) * 3
            trayDirectIconLimit: 3
            notificationHistoryCount: 1
        }

        Bar {
            id: ultra

            width: Config.BarTuning.minimumSupportedWidth
            height: Config.BarTuning.islandHeight
            y: (Config.BarTuning.islandHeight + 4) * 4
            trayDirectIconLimit: 3
            notificationHistoryCount: 1
        }

        Bar {
            id: modeTwoEdge

            width: Config.BarTuning.traySurfaceMinWidth
            height: Config.BarTuning.islandHeight
            y: (Config.BarTuning.islandHeight + 4) * 5
            trayDirectIconLimit: 3
            notificationHistoryCount: 1
        }

        Bar {
            id: modeThreeEdge

            width: Config.BarTuning.traySurfaceMinWidth - 1
            height: Config.BarTuning.islandHeight
            y: (Config.BarTuning.islandHeight + 4) * 6
            trayDirectIconLimit: 3
            notificationHistoryCount: 1
        }

    }

    Timer {
        interval: 0
        running: true
        onTriggered: Qt.callLater(testRoot.runChecks)
    }

}
