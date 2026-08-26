import QtQuick
import Quickshell
import "."

ShellRoot {
    id: testRoot

    property int failureCount: 0
    property int menuToggleCount: 0
    property int idleRequestCount: 0
    property int powerActionCount: 0

    function expect(condition, label) {
        if (condition)
            return
        failureCount += 1
        console.error("[PowerControlsCheck] failed: " + label)
    }

    function expectEqual(actual, expected, label) {
        expect(actual === expected,
               label + ": expected=" + expected + " actual=" + actual)
    }

    function expectNear(actual, expected, label) {
        expect(Math.abs(actual - expected) < 0.01,
               label + ": expected=" + expected + " actual=" + actual)
    }

    function expectSameCenter(containerItem, contentItem, label) {
        const containerCenter = containerItem.mapToItem(
            controls, containerItem.width / 2, containerItem.height / 2)
        const contentCenter = contentItem.mapToItem(
            controls, contentItem.width / 2, contentItem.height / 2)
        expectNear(contentCenter.x, containerCenter.x,
                   label + " horizontal center")
        expectNear(contentCenter.y, containerCenter.y,
                   label + " vertical center")
    }

    function runChecks() {
        expectEqual(controls.topButtonsItem.width, controls.railWidth,
                    "rail width")
        expectEqual(controls.topButtonsItem.height, controls.railHeight,
                    "rail height")
        expectNear(controls.topButtonsItem.radius, controls.railHeight / 2,
                   "rail radius")
        expectNear(controls.width - controls.topButtonsItem.x
                   - controls.topButtonsItem.width, 0,
                   "rail right anchor")

        expectEqual(controls.powerButtonItem.width, controls.controlWidth,
                    "power hit target width")
        expectEqual(controls.powerButtonItem.height, controls.controlHeight,
                    "power hit target height")
        expectEqual(controls.idleToggleButtonItem.width, controls.controlWidth,
                    "idle hit target width")
        expectEqual(controls.idleToggleButtonItem.height, controls.controlHeight,
                    "idle hit target height")

        expectEqual(controls.powerIconItem.width, controls.iconSize,
                    "power vector icon width")
        expectEqual(controls.powerIconItem.height, controls.iconSize,
                    "power vector icon height")
        expectEqual(controls.idleIconItem.width, controls.iconSize,
                    "idle vector icon width")
        expectEqual(controls.idleIconItem.height, controls.iconSize,
                    "idle vector icon height")
        expectEqual(controls.powerIconItem.name, "power",
                    "power vector icon kind")
        expectEqual(controls.idleIconItem.name, "eye-off",
                    "idle enabled vector icon kind")
        expectSameCenter(controls.powerButtonItem, controls.powerIconItem,
                         "power icon")
        expectSameCenter(controls.idleToggleButtonItem, controls.idleIconItem,
                         "idle icon")

        controls.idleEnabled = false
        expectEqual(controls.idleIconItem.name, "eye",
                    "idle disabled vector icon kind")
        controls.idleEnabled = true

        const closedMenuTop = controls.powerMenuItem.y
        controls.powerMenuVisible = true
        expectNear(controls.powerMenuItem.y,
                   controls.topButtonsItem.y
                   + controls.topButtonsItem.height + controls.menuGap,
                   "expanded menu top anchor")
        expectNear(controls.width - controls.powerMenuItem.x
                   - controls.powerMenuItem.width, 0,
                   "expanded menu right anchor")
        controls.powerMenuVisible = false
        expectNear(controls.powerMenuItem.y, closedMenuTop,
                   "menu anchor stable after collapse")
        expectNear(controls.width - controls.powerMenuItem.x
                   - controls.powerMenuItem.width, 0,
                   "collapsed menu right anchor")

        expectEqual(menuToggleCount, 0,
                    "no power side effect on construction")
        expectEqual(idleRequestCount, 0,
                    "no idle side effect on construction")
        expectEqual(powerActionCount, 0,
                    "no power command side effect on construction")

        if (failureCount === 0) {
            console.log("[PowerControlsCheck] PASS")
            Qt.exit(0)
        } else {
            console.error("[PowerControlsCheck] FAIL count=" + failureCount)
            Qt.exit(1)
        }
    }

    PowerControls {
        id: controls

        unit: 16
        reducedMotion: true
        idleEnabled: true
        onPowerMenuToggleRequested: testRoot.menuToggleCount += 1
        onIdleToggleRequested: testRoot.idleRequestCount += 1
        onPowerActionRequested: testRoot.powerActionCount += 1
    }

    Timer {
        interval: 0
        running: true
        onTriggered: Qt.callLater(testRoot.runChecks)
    }
}
