import QtQuick
import Quickshell
import "components"
import "config" as Config

ShellRoot {
    id: testRoot

    property int failureCount: 0
    property int closeCount: 0
    property int stage: 0
    property var sampleEntries: [
        {
            "id": 2,
            "appName": "Second",
            "desktopEntry": "",
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
        property var sourceCounts: []
        signal historyLoaded(var entries, bool recovered, string warning)
        signal historyLoadFailed(string message)
        signal historyAppended()
        signal historyCleared()
        signal operationFailed(string operation, string message)
        signal copySucceeded()
        signal copyFailed(string message)

        function loadHistory() {
            historyCount = testRoot.sampleEntries.length
            sourceCounts = testRoot.sampleEntries.map(entry => ({
                "desktopEntry": entry.desktopEntry || "",
                "appName": entry.appName || "",
                "count": 1
            }))
            historyLoaded(testRoot.sampleEntries, false, "")
        }
        function copyEntry(entry) {
            copySucceeded()
        }
        function clearHistory() {
            historyCount = 0
            sourceCounts = []
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
            reducedMotion: true
            onCloseRequested: testRoot.closeCount += 1
        }
    }

    Timer {
        id: phaseTimer

        interval: 0
        running: true
        onTriggered: {
            if (testRoot.stage === 1) {
                testRoot.expectEqual(panel.selectedSourceKey,
                    "desktop:second",
                    "refresh preserves selected source through aliases")
                testRoot.expectEqual(panel.filteredEntries.length, 1,
                    "refreshed filter keeps one visible entry")
                testRoot.sampleEntries = [testRoot.sampleEntries[1]]
                testRoot.stage = 2
                panel.load()
                phaseTimer.restart()
                return
            }

            if (testRoot.stage === 2) {
                testRoot.expectEqual(panel.selectedSourceKey, "__all__",
                    "deleted source falls back to ALL")
                testRoot.expectEqual(panel.filteredEntries.length, 1,
                    "ALL exposes remaining entry after fallback")

                fakeStore.historyLoadFailed("read failed")
                testRoot.expectEqual(panel.panelState, "error", "load error state")
                panel.load()
                testRoot.expectEqual(panel.panelState, "ready", "retry state")

                panel.clearAll()
                testRoot.expectEqual(panel.panelState, "empty", "clear state")
                testRoot.expectEqual(panel.entries.length, 0,
                    "entries released after clear")
                testRoot.expectEqual(testRoot.closeCount, 1,
                    "close requested after clear")
                testRoot.finish()
                return
            }

            testRoot.expectEqual(panel.implicitHeight,
                Config.BarTuning.rightPanelHeight,
                "fixed shared panel height")
            panel.open = true
            testRoot.expectEqual(panel.panelState, "ready", "load state")
            testRoot.expectEqual(panel.entries.length, 2, "loaded entries")

            panel.switchCard(1)
            testRoot.expectEqual(panel.currentIndex, 1, "next card")
            panel.switchCard(-1)
            testRoot.expectEqual(panel.currentIndex, 0, "previous card")

            panel.copyCurrent()
            testRoot.expectEqual(panel.feedbackMessage, "COPIED", "copy feedback")

            const secondSource = panel.sources.find(source =>
                source.label === "Second")
            testRoot.expectEqual(secondSource !== undefined, true,
                "application source is available")
            panel.selectSource(secondSource.key)
            testRoot.expectEqual(panel.filteredEntries.length, 1,
                "left-click selection filters entries")

            testRoot.sampleEntries = [
                {
                    "id": 2,
                    "appName": "Second",
                    "desktopEntry": "second.desktop",
                    "summary": "Two refreshed",
                    "body": "Body two",
                    "urgency": "Normal",
                    "timestamp": 3000
                },
                testRoot.sampleEntries[1]
            ]
            testRoot.stage = 1
            panel.load()
            phaseTimer.restart()
        }
    }
}
