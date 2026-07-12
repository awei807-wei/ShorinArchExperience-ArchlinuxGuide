import QtQuick
import Quickshell
import "components"

ShellRoot {
    id: testRoot

    property int failureCount: 0

    function fakeItems(count) {
        const items = []
        for (let index = 0; index < count; index++) {
            items.push({
                "icon": "",
                "hasMenu": false,
                "menu": null,
                "activate": function() {}
            })
        }
        return items
    }

    function expectEqual(actual, expected, label) {
        if (actual === expected)
            return
        failureCount += 1
        console.error("[TrayStateCheck] " + label + ": expected=" + expected + " actual=" + actual)
    }

    function expect(value, label) {
        if (value)
            return
        failureCount += 1
        console.error("[TrayStateCheck] failed: " + label)
    }

    function setState(applicationCount, notificationCount) {
        tray.trayItems = fakeItems(applicationCount)
        tray.notificationCount = notificationCount
    }

    function runChecks() {
        setState(4, 0)
        expectEqual(tray.directIconLimit, 3, "direct icon limit")
        expectEqual(tray.hiddenTrayCount, 1, "4 apps -> +1")
        expectEqual(tray.collapsedSlots, 4, "4 apps collapsed slots")

        setState(6, 0)
        expectEqual(tray.hiddenTrayCount, 3, "6 apps -> +3")
        expectEqual(tray.collapsedSlots, 4, "6 apps collapsed slots")

        setState(3, 7)
        expectEqual(tray.hiddenTrayCount, 0, "notification-only hidden count")
        expectEqual(tray.collapsedSlots, 4, "notification-only fourth slot")
        expect(tray.hasCompositeEntry, "notification-only composite entry")

        setState(3, 0)
        expectEqual(tray.collapsedSlots, 3, "no history and no overflow")
        expect(!tray.hasCompositeEntry, "composite disappears at zero")

        setState(6, 8)
        tray.notificationCount = 0
        expectEqual(tray.hiddenTrayCount, 3, "clear keeps application overflow")
        expect(tray.hasCompositeEntry, "clear keeps +3 entry")

        setState(1, 1)
        expectEqual(tray.expandedWidth, tray.unit * 18, "shared minimum width")
        setState(20, 1)
        expect(tray.expandedWidth > tray.unit * 18, "wide tray grows beyond minimum")

        if (failureCount === 0)
            console.log("[TrayStateCheck] PASS")
        else
            console.error("[TrayStateCheck] FAIL count=" + failureCount)
        Qt.quit()
    }

    TrayIsland {
        id: tray
        height: 40
        trayItems: []
    }

    Timer {
        interval: 0
        running: true
        onTriggered: testRoot.runChecks()
    }
}
