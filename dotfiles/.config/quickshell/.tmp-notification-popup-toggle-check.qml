import QtQuick
import Quickshell
import "components"

ShellRoot {
    id: testRoot

    property int failureCount: 0
    property int phase: 0
    property var groupData: ({
        "appName": "Toggle Fixture",
        "notifications": [
            testRoot.makeNotification(1),
            testRoot.makeNotification(2)
        ],
        "critical": false
    })

    function makeNotification(id) {
        return {
            "id": id,
            "summary": "Notification " + id,
            "body": "Body " + id,
            "appName": "Toggle Fixture",
            "desktopEntry": "",
            "appIcon": "",
            "urgency": 1,
            "actions": [],
            "resident": false,
            "expire": function() {},
            "dismiss": function() {}
        }
    }

    function expect(condition, label) {
        if (condition)
            return
        failureCount += 1
        console.error("[NotificationPopupToggleCheck] failed: " + label)
    }

    function finish() {
        if (failureCount === 0) {
            console.log("[NotificationPopupToggleCheck] PASS")
            Qt.exit(0)
        } else {
            console.error("[NotificationPopupToggleCheck] FAIL count=" + failureCount)
            Qt.exit(1)
        }
    }

    FloatingWindow {
        id: hostWindow

        implicitWidth: 400
        implicitHeight: 600
        visible: true
        color: "transparent"

        NotificationPopupGroup {
            id: popup
            anchors.left: parent.left
            anchors.right: parent.right
            group: testRoot.groupData
        }
    }

    Timer {
        id: phaseTimer
        interval: 100
        running: true
        repeat: false

        onTriggered: {
            if (testRoot.phase === 0) {
                testRoot.expect(!popup.expanded, "popup starts collapsed")
                popup.toggleExpandedLater()
                testRoot.expect(!popup.expanded,
                                "toggle is deferred outside the input callback")
                testRoot.phase = 1
                phaseTimer.interval = 40
                phaseTimer.restart()
                return
            }

            if (testRoot.phase === 1) {
                testRoot.expect(popup.expanded, "deferred toggle expands the group")
                popup.toggleExpandedLater()
                testRoot.expect(popup.expanded,
                                "second toggle is also deferred")
                testRoot.phase = 2
                phaseTimer.interval = 40
                phaseTimer.restart()
                return
            }

            testRoot.expect(!popup.expanded, "second deferred toggle collapses the group")
            finish()
        }
    }
}
