import QtQuick
import Quickshell
import "components"

ShellRoot {
    id: testRoot

    property int stage: 0
    property int failureCount: 0
    property int focusCount: 0
    property int closeCount: 0

    function expectEqual(actual, expected, label) {
        if (actual === expected)
            return
        failureCount += 1
        console.error("[TrayInteractionCheck] " + label
                      + ": expected=" + expected + " actual=" + actual)
    }

    function finish() {
        if (failureCount === 0) {
            console.log("[TrayInteractionCheck] PASS")
            Qt.exit(0)
        } else {
            console.error("[TrayInteractionCheck] FAIL count=" + failureCount)
            Qt.exit(1)
        }
    }

    function runChecks() {
        if (stage === 0) {
            tray.scheduleSingleClick()
            stage = 1
            waitTimer.start()
            return
        }

        if (stage === 1) {
            expectEqual(fakeTray.activationCount, 1, "single click activates once")
            expectEqual(focusCount, 0, "single click does not focus")
            fakeTray.activationCount = 0
            tray.scheduleSingleClick()
            tray.focusTrayItemOnDoubleClick()
            stage = 2
            waitTimer.start()
            return
        }

        if (stage === 2) {
            expectEqual(fakeTray.activationCount, 0, "double click cancels pending activate")
            expectEqual(focusCount, 1, "double click requests focus once")
            tray.scheduleSingleClick()
            tray.openTrayMenu()
            stage = 3
            waitTimer.start()
            return
        }

        expectEqual(fakeTray.activationCount, 0, "right-click cancellation does not activate")
        expectEqual(focusCount, 1, "right-click cancellation does not focus")
        finish()
    }

    QtObject {
        id: fakeTray
        property string trayId: "lark_status_icon_1"
        property string title: "Lark"
        property string tooltipTitle: "飞书"
        property string icon: ""
        property bool hasMenu: false
        property var menu: null
        property int activationCount: 0

        function activate() {
            activationCount += 1
        }
    }

    TrayItem {
        id: tray
        trayItem: fakeTray
        onFocusRequested: testRoot.focusCount += 1
        onCloseRequested: testRoot.closeCount += 1
    }

    Timer {
        id: waitTimer
        interval: tray.clickDisambiguationInterval + 20
        repeat: false
        onTriggered: testRoot.runChecks()
    }

    Timer {
        interval: 0
        running: true
        onTriggered: testRoot.runChecks()
    }
}
