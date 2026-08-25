import QtQuick
import Quickshell
import "components/TrayNotificationModel.js" as TrayModel

ShellRoot {
    id: testRoot

    property int failureCount: 0

    function expect(condition, label) {
        if (condition)
            return
        failureCount += 1
        console.error("[NotificationSourceModelCheck] failed: " + label)
    }

    function expectEqual(actual, expected, label) {
        if (actual === expected)
            return
        failureCount += 1
        console.error("[NotificationSourceModelCheck] " + label
                      + ": expected=" + expected + " actual=" + actual)
    }

    function entry(id, appName, desktopEntry, timestamp, appIcon) {
        return {
            "id": id,
            "appName": appName,
            "desktopEntry": desktopEntry,
            "appIcon": appIcon || "",
            "summary": "Notice " + id,
            "body": "",
            "urgency": "Normal",
            "timestamp": timestamp
        }
    }

    function trayItem(id, title, icon, hasMenu) {
        return {
            "id": id,
            "title": title,
            "tooltipTitle": title,
            "tooltipDescription": "",
            "icon": icon || "",
            "hasMenu": hasMenu === true,
            "menu": hasMenu === true ? {"title": title + " menu"} : null
        }
    }

    function sourceWithLabel(sources, label) {
        return sources.find(source => source.label === label)
    }

    function runAliasAndIconChecks() {
        const history = [
            entry(1, "Telegram Desktop", "", 300, "telegram-new"),
            entry(2, "Telegram Desktop", "org.telegram.desktop", 200,
                  "telegram-old"),
            entry(3, "Other", "other.desktop", 100, "")
        ]
        const sources = TrayModel.buildHistorySources(history, [], [])
        const telegram = sourceWithLabel(sources, "Telegram Desktop")

        expectEqual(sources[0].key, "__all__", "ALL stays first")
        expectEqual(sources[0].count, history.length, "ALL counts every entry")
        expectEqual(sources.length, 3, "shared aliases merge two records")
        expectEqual(telegram.count, 2, "Telegram alias count")
        expect(telegram.aliases.indexOf("desktop:org.telegram") >= 0,
               "Telegram desktop alias retained")
        expect(telegram.aliases.indexOf("app:telegram desktop") >= 0,
               "Telegram app alias retained")
        expectEqual(telegram.iconSource, "telegram-new",
                    "latest non-empty appIcon wins")

        const legacy = TrayModel.buildHistorySources([
            entry(4, "Legacy", "legacy.desktop", 50)
        ], [], [])
        expectEqual(legacy[1].iconSource, "",
                    "legacy history without appIcon stays readable")
    }

    function runOrderingChecks() {
        const kitty = trayItem("kitty", "Kitty", "kitty-tray", true)
        const idleOne = trayItem("idle-one", "Idle One", "idle-one", true)
        const telegram = trayItem("org.telegram.desktop", "Telegram Desktop",
                                  "telegram-tray", true)
        const idleTwo = trayItem("idle-two", "Idle Two", "idle-two", false)
        const history = [
            entry(1, "Recent", "recent.desktop", 900),
            entry(2, "Telegram Desktop", "org.telegram.desktop", 800,
                  "telegram-history"),
            entry(3, "Kitty", "kitty.desktop", 700, "kitty-history"),
            entry(4, "Older", "older.desktop", 100)
        ]
        const counts = [
            {"desktopEntry": "kitty.desktop", "appName": "Kitty", "count": 1},
            {"desktopEntry": "org.telegram.desktop", "appName": "Telegram Desktop", "count": 3}
        ]
        const sources = TrayModel.buildHistorySources(
            history, [kitty, idleOne, telegram, idleTwo], counts)

        expectEqual(sources.map(source => source.label).join(","),
                    "ALL,Idle One,Idle Two,Kitty,Telegram Desktop,Recent,Older",
                    "all tray items use ascending count before non-tray sources")
        const telegramSource = sourceWithLabel(sources, "Telegram Desktop")
        const idleSource = sourceWithLabel(sources, "Idle One")
        expect(telegramSource.trayItem === telegram,
               "History keeps the matched live tray object")
        expectEqual(telegramSource.iconSource, "telegram-tray",
                    "live tray icon has highest priority")
        expect(telegramSource.trayItem.hasMenu,
               "tray-backed source exposes menu")
        expectEqual(idleSource.count, 0,
                    "registered tray source without history has zero count")
        expectEqual(idleSource.entries.length, 0,
                    "registered tray source without history has empty entries")
        expect(idleSource.trayBacked && idleSource.trayItem === idleOne,
               "zero-count source retains live tray ownership")
        const recentSource = sourceWithLabel(sources, "Recent")
        expect(!recentSource.trayBacked && recentSource.trayItem === null,
               "non-tray source does not invent a menu owner")
        expectEqual(TrayModel.sortedItems(
                        [kitty, idleOne, telegram, idleTwo], counts)
                        .map(item => item.title).join(","),
                    "Telegram Desktop,Kitty,Idle One,Idle Two",
                    "top bar keeps its existing descending count order")

        const tieSources = TrayModel.buildHistorySources([
            entry(5, "Zulu", "zulu.desktop", 100),
            entry(6, "Alpha", "alpha.desktop", 100)
        ], [], [])
        expectEqual(tieSources.map(source => source.label).join(","),
                    "ALL,Alpha,Zulu", "non-tray ties use label order")
    }

    function runTrayMergeAndProtectionChecks() {
        const shared = trayItem("merge-id", "Shared Menu", "shared-icon", true)
        const merged = TrayModel.buildHistorySources([
            entry(1, "Alpha", "merge-id.desktop", 200),
            entry(2, "Shared Menu", "", 100)
        ], [shared], [])
        expectEqual(merged.length, 2,
                    "two identities targeting one tray item merge")
        expectEqual(merged[1].count, 2, "merged tray source keeps both entries")
        expect(merged[1].trayItem === shared, "merged source keeps tray object")

        const ambiguousItems = [
            trayItem("org.example.App.desktop", "Unique App", "", true),
            trayItem("/opt/org.example.App.desktop", "Other", "", true)
        ]
        const ambiguousIndex = TrayModel.trayIndexForSource(
            ambiguousItems, "org.example.App.desktop", "Unique App")
        expectEqual(ambiguousIndex, -1,
                    "ambiguous Desktop Entry blocks appName fallback")
        const ambiguous = TrayModel.buildHistorySources([
            entry(3, "Unique App", "org.example.App.desktop", 300)
        ], ambiguousItems, [])
        const ambiguousHistory = ambiguous.find(source =>
            source.key !== "__all__" && source.entries.length === 1)
        expect(ambiguous.length === 4,
               "ambiguous registered items still appear as zero-count sources")
        expect(!ambiguousHistory.trayBacked,
               "ambiguous source is not assigned to a tray item")

        const chrome = trayItem("chrome_status_icon_1", "Chrome", "", true)
        const qq = trayItem("chrome_status_icon_1", "", "qq-icon", true)
        qq.tooltipTitle = ""
        const qqSources = TrayModel.buildHistorySources([
            entry(4, "QQ", "QQ.desktop", 400)
        ], [chrome, qq], [])
        const qqHistory = qqSources.find(source =>
            source.key !== "__all__" && source.entries.length === 1)
        expect(qqHistory.trayItem === qq, "QQ fallback maps blank chrome item")
        expectEqual(sourceWithLabel(qqSources, "Chrome").count, 0,
                    "unmatched Chrome tray item remains visible")
    }

    function runUnconditionalTrayChecks() {
        const first = trayItem("first.desktop", "First Tray", "first", false)
        const second = trayItem("second.desktop", "Second Tray", "second", true)
        const sources = TrayModel.buildHistorySources([], [first, second], [])

        expectEqual(sources.map(source => source.label).join(","),
                    "ALL,First Tray,Second Tray",
                    "empty history still exposes every registered tray item")
        expectEqual(sources[0].count, 0, "empty ALL source has zero count")
        expect(sources.slice(1).every(source => source.trayBacked),
               "every synthesized source is tray-backed")
        expect(sources[2].trayItem.hasMenu,
               "zero-count tray source retains native menu capability")

        const previousKey = sources[2].key
        const previousAliases = sources[2].aliases
        const refreshed = TrayModel.buildHistorySources([
            entry(9, "Second Tray", "second.desktop", 500)
        ], [first, second], [])
        expectEqual(TrayModel.sourceKeyForSelection(
                        refreshed, previousKey, previousAliases),
                    "desktop:second",
                    "first history entry preserves a selected tray-only source")
    }

    function runLifecycleAndSelectionChecks() {
        const history = [entry(1, "Late Application", "late.desktop", 100)]
        const before = TrayModel.buildHistorySources(history, [], [])
        const liveItem = trayItem("late", "Late Application", "live-icon", true)
        const live = TrayModel.buildHistorySources(history, [liveItem], [])
        const after = TrayModel.buildHistorySources(history, [], [])

        expect(!before[1].trayBacked, "source starts in ordinary section")
        expect(live[1].trayBacked, "new tray item promotes existing source")
        expectEqual(after[1].count, 1,
                    "source remains after tray item disappears")

        const oldSources = TrayModel.buildHistorySources([
            entry(2, "Telegram Desktop", "", 200)
        ], [], [])
        const previousKey = oldSources[1].key
        const previousAliases = oldSources[1].aliases
        const refreshed = TrayModel.buildHistorySources([
            entry(3, "Telegram Desktop", "org.telegram.desktop", 300),
            entry(2, "Telegram Desktop", "", 200)
        ], [], [])
        expectEqual(TrayModel.sourceKeyForSelection(
                        refreshed, previousKey, previousAliases),
                    "desktop:org.telegram",
                    "refresh preserves selection through shared alias")
        expectEqual(TrayModel.sourceKeyForSelection(
                        TrayModel.buildHistorySources([], [], []),
                        previousKey, previousAliases),
                    "__all__", "deleted source falls back to ALL")
        expect(TrayModel.sourceForKey(refreshed,
                    "desktop:org.telegram") !== null,
               "sourceForKey resolves rebuilt source")
    }

    function finish() {
        runAliasAndIconChecks()
        runOrderingChecks()
        runTrayMergeAndProtectionChecks()
        runUnconditionalTrayChecks()
        runLifecycleAndSelectionChecks()
        if (failureCount === 0) {
            console.log("[NotificationSourceModelCheck] PASS")
            Qt.exit(0)
        } else {
            console.error("[NotificationSourceModelCheck] FAIL count="
                          + failureCount)
            Qt.exit(1)
        }
    }

    Timer {
        interval: 0
        running: true
        onTriggered: testRoot.finish()
    }
}
