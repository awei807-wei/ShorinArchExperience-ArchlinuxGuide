import QtQuick
import Quickshell
import "."

ShellRoot {
    id: testRoot

    property int failureCount: 0
    property int menuToggleCount: 0
    property int idleRequestCount: 0
    property int powerActionCount: 0
    property string lastPowerAction: ""

    function expect(condition, label) {
        if (condition)
            return
        failureCount += 1
        console.error("[PowerControlsCheck] failed: " + label)
    }

    function expectEqual(actual, expected, label) {
        expect(actual === expected, label + ": expected=" + expected + " actual=" + actual)
    }

    function expectNear(actual, expected, label) {
        expect(Math.abs(actual - expected) < 0.01,
               label + ": expected=" + expected + " actual=" + actual)
    }

    function runChecks() {
        expectEqual(controls.powerButtonItem.width, controls.idleToggleButtonItem.width,
                    "button widths")
        expectEqual(controls.powerButtonItem.height, controls.idleToggleButtonItem.height,
                    "button heights")
        expectNear(controls.powerButtonItem.y + controls.powerButtonItem.height / 2,
                   controls.idleToggleButtonItem.y + controls.idleToggleButtonItem.height / 2,
                   "button vertical center")
        expectEqual(controls.powerButtonItem.width, controls.buttonDiameter,
                    "power hit target diameter")
        expectEqual(controls.idleToggleButtonItem.width, controls.buttonDiameter,
                    "idle hit target diameter")

        expectEqual(controls.powerIconItem.width, controls.powerButtonItem.width,
                    "power icon fills button width")
        expectEqual(controls.powerIconItem.height, controls.powerButtonItem.height,
                    "power icon fills button height")
        expectEqual(controls.idleIconItem.width, controls.idleToggleButtonItem.width,
                    "idle icon fills button width")
        expectEqual(controls.idleIconItem.height, controls.idleToggleButtonItem.height,
                    "idle icon fills button height")
        expectEqual(controls.powerIconItem.horizontalAlignment, Text.AlignHCenter,
                    "power icon horizontal alignment")
        expectEqual(controls.powerIconItem.verticalAlignment, Text.AlignVCenter,
                    "power icon vertical alignment")
        expectEqual(controls.idleIconItem.horizontalAlignment, Text.AlignHCenter,
                    "idle icon horizontal alignment")
        expectEqual(controls.idleIconItem.verticalAlignment, Text.AlignVCenter,
                    "idle icon vertical alignment")
        expectEqual(controls.powerIconItem.font.family, controls.iconFontFamily,
                    "power icon font family")
        expectEqual(controls.idleIconItem.font.family, controls.iconFontFamily,
                    "idle icon font family")
        expectEqual(controls.powerIconItem.text, "\uf011", "power glyph")
        expectEqual(controls.idleIconItem.text, "\uf070", "enabled idle glyph")

        const closedMenuRight = controls.width - controls.powerMenuItem.x - controls.powerMenuItem.width
        expectNear(closedMenuRight, 0, "closed menu right anchor")
        const closedMenuTop = controls.powerMenuItem.y
        controls.powerMenuVisible = true
        expectNear(controls.powerMenuItem.y,
                   controls.topButtonsItem.y + controls.topButtonsItem.height + controls.menuGap,
                   "expanded menu top anchor")
        expectNear(controls.width - controls.powerMenuItem.x - controls.powerMenuItem.width,
                   0,
                   "expanded menu right anchor")
        controls.powerMenuVisible = false
        expectNear(controls.powerMenuItem.y, closedMenuTop, "menu anchor stable after collapse")
        expectNear(controls.width - controls.powerMenuItem.x - controls.powerMenuItem.width,
                   0,
                   "collapsed menu right anchor")

        expectEqual(controls.powerMenuVisible, false, "menu starts collapsed")
        expectEqual(menuToggleCount, 0, "no power side effect on construction")
        expectEqual(idleRequestCount, 0, "no idle side effect on construction")
        expectEqual(powerActionCount, 0, "no power command side effect on construction")

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
        idleEnabled: true
        onPowerMenuToggleRequested: testRoot.menuToggleCount += 1
        onIdleToggleRequested: testRoot.idleRequestCount += 1
        onPowerActionRequested: function(action) {
            testRoot.powerActionCount += 1
            testRoot.lastPowerAction = action
        }
    }

    Timer {
        interval: 0
        running: true
        onTriggered: Qt.callLater(testRoot.runChecks)
    }
}
