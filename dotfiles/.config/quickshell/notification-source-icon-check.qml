import QtQuick
import Quickshell
import "components"

ShellRoot {
    id: testRoot

    property int attempts: 0
    property int failureCount: 0

    function expect(condition, label) {
        if (condition)
            return
        failureCount += 1
        console.error("[NotificationSourceIconCheck] failed: " + label)
    }

    Item {
        width: 60
        height: 60

        NotificationSourceTab {
            id: sourceTab

            source: ({
                "key": "app:fixture",
                "label": "Fixture",
                "count": 1,
                "iconSource": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
                "desktopEntry": "",
                "appName": "",
                "trayItem": null
            })
        }
    }

    Timer {
        interval: 20
        running: true

        onTriggered: {
            if (!sourceTab.displayingIcon && testRoot.attempts < 20) {
                testRoot.attempts += 1
                restart()
                return
            }
            testRoot.expect(sourceTab.displayingIcon,
                            "ready URL image is visible")
            testRoot.expect(!sourceTab.displayingFallback,
                            "fallback letter is hidden for a ready image")
            if (testRoot.failureCount === 0) {
                console.log("[NotificationSourceIconCheck] PASS")
                Qt.exit(0)
            } else {
                console.error("[NotificationSourceIconCheck] FAIL count="
                              + testRoot.failureCount)
                Qt.exit(1)
            }
        }
    }
}
