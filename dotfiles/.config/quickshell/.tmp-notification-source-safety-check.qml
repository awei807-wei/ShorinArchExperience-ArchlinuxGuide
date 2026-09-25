import QtQuick
import Quickshell
import "components"

ShellRoot {
    id: testRoot

    property int failureCount: 0
    property int attempts: 0

    function expect(condition, label) {
        if (condition)
            return
        failureCount += 1
        console.error("[NotificationSourceSafetyCheck] failed: " + label)
    }

    Item {
        width: 120
        height: 60

        NotificationSourceTab {
            id: transientOnly
            source: ({
                "key": "transient",
                "label": "Transient",
                "count": 1,
                "iconSource": "file:///tmp/.org.chromium.Chromium.fixture/logo.png",
                "desktopEntry": "",
                "appName": "Human readable name",
                "trayItem": null
            })
        }

        NotificationSourceTab {
            id: fallbackTab
            x: 60
            source: ({
                "key": "fallback",
                "label": "Fallback",
                "count": 1,
                "iconSource": "file:///definitely/missing/icon.png",
                "desktopEntry": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
                "appName": "Human readable name",
                "trayItem": null
            })
        }
    }

    Timer {
        interval: 20
        running: true
        repeat: false

        onTriggered: {
            testRoot.expect(transientOnly.iconCandidates.length === 0,
                            "ephemeral Chromium file and appName are rejected")
            if (!fallbackTab.displayingIcon && testRoot.attempts < 20) {
                testRoot.attempts += 1
                restart()
                return
            }
            testRoot.expect(fallbackTab.displayingIcon,
                            "a stale first candidate falls back to the next icon")
            if (testRoot.failureCount === 0) {
                console.log("[NotificationSourceSafetyCheck] PASS")
                Qt.exit(0)
            } else {
                console.error("[NotificationSourceSafetyCheck] FAIL count="
                              + testRoot.failureCount)
                Qt.exit(1)
            }
        }
    }
}
