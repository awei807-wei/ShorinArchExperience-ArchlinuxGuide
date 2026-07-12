import QtQuick
import Quickshell
import "components"

ShellRoot {
    id: testRoot

    property int failureCount: 0
    property int closeCount: 0
    property var sampleEntries: [
        {
            "id": 2,
            "appName": "Second",
            "desktopEntry": "second.desktop",
            "summary": "Two",
            "body": "Body two",
            "urgency": "Normal",
            "timestamp": 2000
        },
        {
            "id": 1,
            "appName": "First",
            "desktopEntry": "first.desktop",
            "summary": "One",
            "body": "Body one",
            "urgency": "Low",
            "timestamp": 1000
        }
    ]

    function expectEqual(actual, expected, label) {
        if (actual === expected)
            return
        failureCount += 1
        console.error("[NotificationPanelCheck] " + label + ": expected=" + expected + " actual=" + actual)
    }

    function finish() {
        if (failureCount === 0)
            console.log("[NotificationPanelCheck] PASS")
        else
            console.error("[NotificationPanelCheck] FAIL count=" + failureCount)
        Qt.quit()
    }

    QtObject {
        id: fakeStore
        property int historyCount: 2
        signal historyLoaded(var entries, bool recovered, string warning)
        signal historyLoadFailed(string message)
        signal historyAppended()
        signal historyCleared()
        signal operationFailed(string operation, string message)
        signal copySucceeded()
        signal copyFailed(string message)

        function loadHistory() {
            historyLoaded(testRoot.sampleEntries, false, "")
        }
        function copyEntry(entry) {
            copySucceeded()
        }
        function clearHistory() {
            historyCount = 0
            historyCleared()
        }
    }

    Item {
        width: 396
        height: 300

        TrayNotificationPanel {
            id: panel
            width: 396
            height: 290
            store: fakeStore
            open: false
            onCloseRequested: testRoot.closeCount += 1
        }
    }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            panel.open = true
            testRoot.expectEqual(panel.panelState, "ready", "load state")
            testRoot.expectEqual(panel.entries.length, 2, "loaded entries")

            panel.switchCard(1)
            testRoot.expectEqual(panel.currentIndex, 1, "next card")
            panel.switchCard(-1)
            testRoot.expectEqual(panel.currentIndex, 0, "previous card")

            panel.copyCurrent()
            testRoot.expectEqual(panel.feedbackMessage, "COPIED", "copy feedback")

            fakeStore.historyLoadFailed("read failed")
            testRoot.expectEqual(panel.panelState, "error", "load error state")
            panel.load()
            testRoot.expectEqual(panel.panelState, "ready", "retry state")

            panel.clearAll()
            testRoot.expectEqual(panel.panelState, "empty", "clear state")
            testRoot.expectEqual(panel.entries.length, 0, "entries released after clear")
            testRoot.expectEqual(testRoot.closeCount, 1, "close requested after clear")
            testRoot.finish()
        }
    }
}
