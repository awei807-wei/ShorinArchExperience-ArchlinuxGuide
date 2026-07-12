import QtQuick
import Quickshell
import "components"

ShellRoot {
    id: testRoot

    property int stage: 0
    property int failureCount: 0

    function expectEqual(actual, expected, label) {
        if (actual === expected)
            return
        failureCount += 1
        console.error("[NotificationStoreCheck] " + label + ": expected=" + expected + " actual=" + actual)
    }

    function finish() {
        if (failureCount === 0)
            console.log("[NotificationStoreCheck] PASS")
        else
            console.error("[NotificationStoreCheck] FAIL count=" + failureCount)
        Qt.quit()
    }

    NotificationHistoryStore {
        id: store

        onHistoryLoaded: (entries, recovered, warning) => {
            testRoot.expectEqual(entries.length, 4, "bounded loaded entry count")
            testRoot.expectEqual(entries[0].id, 9, "newest entry first")
            testRoot.expectEqual(entries[1].id, 8, "second newest entry")
            testRoot.expectEqual(entries[2].id, 7, "third newest entry")
            testRoot.expectEqual(entries[3].id, 0, "active append is retained")
            testRoot.stage = 3
            store.clearHistory()
        }

        onHistoryCleared: {
            testRoot.expectEqual(store.historyCount, 0, "count after clear")
            testRoot.finish()
        }

        onOperationFailed: (operation, message) => {
            testRoot.failureCount += 1
            console.error("[NotificationStoreCheck] " + operation + " failed: " + message)
            testRoot.finish()
        }
    }

    Timer {
        interval: 20
        repeat: true
        running: true
        onTriggered: {
            if (store.busy)
                return

            if (testRoot.stage === 0) {
                testRoot.expectEqual(store.historyCount, 0, "initial count")
                const copyText = store.entryText({
                    "id": 42,
                    "appName": "Copy Source",
                    "desktopEntry": "copy.desktop",
                    "summary": "Copy title",
                    "body": "Copy body",
                    "urgency": "Critical",
                    "timestamp": 2000
                })
                testRoot.expectEqual(copyText.includes("Copy Source"), true, "copy source")
                testRoot.expectEqual(copyText.includes("copy.desktop"), true, "copy desktop entry")
                testRoot.expectEqual(copyText.includes("Copy title"), true, "copy title")
                testRoot.expectEqual(copyText.includes("Copy body"), true, "copy body")
                testRoot.expectEqual(copyText.includes("通知 ID: 42"), true, "copy notification id")
                testRoot.stage = 1
                store.maxPendingAppends = 3
                for (let index = 0; index < 10; index++) {
                    store.appendSnapshot({
                        "id": index,
                        "appName": "Application " + index,
                        "desktopEntry": "app-" + index + ".desktop",
                        "summary": "Notification " + index,
                        "body": "Body " + index,
                        "urgency": "Normal",
                        "timestamp": index * 1000
                    })
                }
            } else if (testRoot.stage === 1) {
                testRoot.expectEqual(store.historyCount, 4, "count after bounded appends")
                testRoot.stage = 2
                store.loadHistory()
            }
        }
    }
}
