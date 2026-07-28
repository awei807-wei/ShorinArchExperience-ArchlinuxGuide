import QtQuick
import Quickshell
import "."

ShellRoot {
    id: testRoot

    property int failureCount: 0

    function expect(condition, label) {
        if (condition)
            return
        failureCount += 1
        console.error("[BarLayoutCheck] failed: " + label)
    }

    function expectEqual(actual, expected, label) {
        if (actual === expected)
            return
        failureCount += 1
        console.error("[BarLayoutCheck] " + label
            + ": expected=" + expected + " actual=" + actual)
    }

    function expectNoOverlap(target, label) {
        expect(target.contextRight + target.islandGap <= target.clockLeft,
            label + " context/clock overlap")
        expect(target.clockRight + target.islandGap <= target.systemLeft,
            label + " clock/system overlap")
    }

    function runChecks() {
        expectEqual(wide.layoutMode, 0, "2048 layout mode")
        expectEqual(wide.islandHeight, 38, "fixed island height")
        expectEqual(wide.showWeather, true, "2048 weather visible")
        expectEqual(wide.actualTrayIconLimit, 3, "2048 tray icons")
        expectEqual(wide.metricDetailsVisible, true, "2048 metric detail")
        expectEqual(wide.contextRight, 238, "2048 context width")
        expectEqual(wide.centerIsland.width, 300, "2048 clock width")
        expectEqual(wide.systemWidth, 510, "2048 system width")
        expectNoOverlap(wide, "2048")

        expectEqual(standard.layoutMode, 1, "1280 layout mode")
        expectEqual(standard.showWeather, false, "1280 weather hidden")
        expectEqual(standard.actualTrayIconLimit, 3, "1280 tray retained after weather removal")
        expectEqual(standard.metricDetailsVisible, true, "1280 metric detail retained")
        expectNoOverlap(standard, "1280")

        expectEqual(compact.layoutMode, 2, "1024 layout mode")
        expectEqual(compact.showWeather, false, "1024 weather hidden")
        expectEqual(compact.actualTrayIconLimit, 0, "1024 direct tray icons hidden")
        expectEqual(compact.trayVisible, true, "1024 tray overflow entry retained")
        expectEqual(compact.metricDetailsVisible, true, "1024 metric detail retained")
        expectNoOverlap(compact, "1024")

        expectEqual(narrow.layoutMode, 3, "800 layout mode")
        expectEqual(narrow.showWeather, false, "800 weather hidden")
        expectEqual(narrow.trayVisible, false, "800 tray surface hidden")
        expectEqual(narrow.metricDetailsVisible, false, "800 secondary metric detail hidden")
        expectNoOverlap(narrow, "800")

        if (failureCount === 0)
            console.log("[BarLayoutCheck] PASS")
        else
            console.error("[BarLayoutCheck] FAIL count=" + failureCount)
        Qt.quit()
    }

    Item {
        width: 2048
        height: 200

        Bar {
            id: wide
            width: 2048
            height: 38
            trayDirectIconLimit: 3
        }

        Bar {
            id: standard
            width: 1280
            height: 38
            y: 42
            trayDirectIconLimit: 3
        }

        Bar {
            id: compact
            width: 1024
            height: 38
            y: 84
            trayDirectIconLimit: 3
        }

        Bar {
            id: narrow
            width: 800
            height: 38
            y: 126
            trayDirectIconLimit: 3
        }
    }

    Timer {
        interval: 0
        running: true
        onTriggered: testRoot.runChecks()
    }
}
