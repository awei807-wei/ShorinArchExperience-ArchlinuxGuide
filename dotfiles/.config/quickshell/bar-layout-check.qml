import "."
import QtQuick
import Quickshell

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
        expect(target.contextRight + target.islandGap <= target.clockLeft, label + " context/clock overlap");
        expect(target.clockRight + target.islandGap <= target.systemLeft, label + " clock/system overlap");
    }

    function runChecks() {
        expectEqual(wide.layoutMode, 0, "2048 layout mode");
        expectEqual(wide.islandHeight, 38, "fixed island height");
        expectEqual(wide.showWeather, true, "2048 weather visible");
        expectEqual(wide.actualTrayIconLimit, 3, "2048 tray icons");
        expectEqual(wide.metricDetailsVisible, true, "2048 metric detail");
        expectEqual(wide.contextWidth, 200, "2048 context width");
        expectEqual(wide.clockWidth, 280, "2048 clock width");
        expectEqual(wide.metricsWidth, 288, "2048 metrics width");
        expectEqual(wide.systemWidth, 442, "2048 system width");
        expectEqual(wide.systemSpacing, 8, "2048 metrics/utility gap");
        expectEqual(wide.utilitySpacing, 4, "2048 tray/power gap");
        expectNoOverlap(wide, "2048");
        expectEqual(standard.layoutMode, 1, "1280 layout mode");
        expectEqual(standard.showWeather, false, "1280 weather hidden");
        expectEqual(standard.actualTrayIconLimit, 3, "1280 tray retained after weather removal");
        expectEqual(standard.metricDetailsVisible, true, "1280 metric detail retained");
        expectEqual(standard.contextWidth, 200, "1280 context width");
        expectEqual(standard.clockWidth, 212, "1280 clock width");
        expectEqual(standard.metricsWidth, 288, "1280 metrics width");
        expectEqual(standard.systemWidth, 442, "1280 system width");
        expectNoOverlap(standard, "1280");
        expectEqual(compact.layoutMode, 2, "1024 layout mode");
        expectEqual(compact.showWeather, false, "1024 weather hidden");
        expectEqual(compact.actualTrayIconLimit, 0, "1024 direct tray icons hidden");
        expectEqual(compact.trayVisible, true, "1024 tray overflow entry retained");
        expectEqual(compact.metricDetailsVisible, true, "1024 metric detail retained");
        expectEqual(compact.contextWidth, 200, "1024 context width");
        expectEqual(compact.clockWidth, 212, "1024 clock width");
        expectEqual(compact.metricsWidth, 288, "1024 metrics width");
        expectEqual(compact.systemWidth, 376, "1024 system width");
        expectNoOverlap(compact, "1024");
        expectEqual(narrow.layoutMode, 3, "800 layout mode");
        expectEqual(narrow.showWeather, false, "800 weather hidden");
        expectEqual(narrow.trayVisible, false, "800 tray surface hidden");
        expectEqual(narrow.metricDetailsVisible, false, "800 secondary metric detail hidden");
        expectEqual(narrow.contextWidth, 184, "800 context width");
        expectEqual(narrow.clockWidth, 176, "800 clock width");
        expectEqual(narrow.metricsWidth, 220, "800 metrics width");
        expectEqual(narrow.systemWidth, 266, "800 system width");
        expectNoOverlap(narrow, "800");
        expectEqual(ultra.layoutMode, 4, "660 layout mode");
        expectEqual(ultra.showWeather, false, "660 weather hidden");
        expectEqual(ultra.trayVisible, false, "660 tray surface hidden");
        expectEqual(ultra.metricDetailsVisible, false, "660 metric detail hidden");
        expectEqual(ultra.contextWidth, 172, "660 context width");
        expectEqual(ultra.clockWidth, 160, "660 clock width");
        expectEqual(ultra.metricsWidth, 176, "660 metrics width");
        expectEqual(ultra.systemWidth, 222, "660 system width");
        expectNoOverlap(ultra, "660");
        expectEqual(modeTwoEdge.layoutMode, 2, "980 layout mode");
        expectEqual(modeTwoEdge.clockRight + modeTwoEdge.islandGap, modeTwoEdge.systemLeft, "980 exact clock/system boundary");
        expectNoOverlap(modeTwoEdge, "980");
        expectEqual(modeThreeEdge.layoutMode, 3, "979 layout mode");
        expectNoOverlap(modeThreeEdge, "979");
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
        height: 310

        Bar {
            id: wide

            width: 2048
            height: 38
            trayDirectIconLimit: 3
            notificationHistoryCount: 1
        }

        Bar {
            id: standard

            width: 1280
            height: 38
            y: 42
            trayDirectIconLimit: 3
            notificationHistoryCount: 1
        }

        Bar {
            id: compact

            width: 1024
            height: 38
            y: 84
            trayDirectIconLimit: 3
            notificationHistoryCount: 1
        }

        Bar {
            id: narrow

            width: 800
            height: 38
            y: 126
            trayDirectIconLimit: 3
            notificationHistoryCount: 1
        }

        Bar {
            id: ultra

            width: 660
            height: 38
            y: 168
            trayDirectIconLimit: 3
            notificationHistoryCount: 1
        }

        Bar {
            id: modeTwoEdge

            width: 980
            height: 38
            y: 210
            trayDirectIconLimit: 3
            notificationHistoryCount: 1
        }

        Bar {
            id: modeThreeEdge

            width: 979
            height: 38
            y: 252
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
