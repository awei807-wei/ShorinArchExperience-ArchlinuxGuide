import QtQuick
import Quickshell
import "components"
import "config" as Config
import "components/TrayNotificationModel.js" as TrayModel

ShellRoot {
    id: testRoot

    property int failureCount: 0

    function fakeItems(count) {
        const items = [];
        for (let index = 0; index < count; index++) {
            items.push({
                "id": "app-" + (index + 1),
                "title": "Application " + (index + 1),
                "tooltipTitle": "Application " + (index + 1),
                "icon": "",
                "hasMenu": false,
                "menu": null,
                "activate": function() {
                }
            });
        }
        return items;
    }

    function itemIds(items) {
        return items.map(item => item.id !== undefined ? item.id : item.trayId).join(",");
    }

    function expectEqual(actual, expected, label) {
        if (actual === expected)
            return ;

        failureCount += 1;
        console.error("[TrayStateCheck] " + label + ": expected=" + expected + " actual=" + actual);
    }

    function expect(value, label) {
        if (value)
            return ;

        failureCount += 1;
        console.error("[TrayStateCheck] failed: " + label);
    }

    function setState(applicationCount, notificationCount) {
        tray.trayItems = fakeItems(applicationCount);
        tray.notificationCount = notificationCount;
    }

    function runChecks() {
        setState(0, 0);
        expectEqual(tray.collapsedSlots, 1, "empty tray keeps one slot");
        expectEqual(tray.implicitWidth, Config.BarTuning.trayMinimumWidth, "empty tray minimum width");
        setState(1, 0);
        expectEqual(tray.collapsedSlots, 1, "1 app -> 1 slot");
        expectEqual(tray.implicitWidth, Config.BarTuning.trayMinimumWidth, "1 app width");
        setState(2, 0);
        expectEqual(tray.collapsedSlots, 2, "2 apps -> 2 slots");
        expectEqual(tray.implicitWidth, 2 * tray.itemWidth + tray.itemGap + tray.horizontalPadding, "2 apps width");
        setState(3, 0);
        expectEqual(tray.collapsedSlots, 3, "3 apps -> 3 slots");
        expectEqual(tray.implicitWidth, 3 * tray.itemWidth + 2 * tray.itemGap + tray.horizontalPadding, "3 apps width");
        setState(4, 0);
        expectEqual(tray.directIconLimit, 3, "direct icon limit");
        expectEqual(tray.hiddenTrayCount, 1, "4 apps -> +1");
        expectEqual(tray.collapsedSlots, 4, "4 apps collapsed slots");
        expectEqual(tray.implicitWidth, Config.BarTuning.trayMaximumCollapsedWidth, "overflow width");
        expectEqual(tray.iconSize, Config.BarTuning.trayIconSize, "tray icons use configured size");
        setState(6, 0);
        expectEqual(tray.hiddenTrayCount, 3, "6 apps -> +3");
        expectEqual(tray.collapsedSlots, 4, "6 apps collapsed slots");
        setState(3, 7);
        expectEqual(tray.hiddenTrayCount, 0, "notification-only hidden count");
        expectEqual(tray.collapsedSlots, 4, "notification-only fourth slot");
        expect(tray.hasCompositeEntry, "notification-only composite entry");
        setState(3, 0);
        expectEqual(tray.collapsedSlots, 3, "no history and no overflow");
        expect(!tray.hasCompositeEntry, "composite disappears at zero");
        setState(6, 8);
        tray.notificationCount = 0;
        expectEqual(tray.hiddenTrayCount, 3, "clear keeps application overflow");
        expect(tray.hasCompositeEntry, "clear keeps +3 entry");
        setState(1, 1);
        expectEqual(tray.expandedWidth, Config.BarTuning.trayExpandedMinWidth, "shared minimum width");
        setState(20, 1);
        expect(tray.expandedWidth > Config.BarTuning.trayExpandedMinWidth, "wide tray grows beyond minimum");

        const orderedItems = fakeItems(4);
        let sources = [{
            "desktopEntry": "/usr/share/applications/app-4.desktop",
            "appName": "",
            "count": 1
        }];
        expectEqual(itemIds(tray.sortedItems(orderedItems, sources)),
                    "app-4,app-1,app-2,app-3", "one notification promotes app 4");
        sources = [{
            "desktopEntry": "app-4.desktop",
            "appName": "",
            "count": 1
        }, {
            "desktopEntry": "app-3.desktop",
            "appName": "",
            "count": 2
        }];
        expectEqual(itemIds(tray.sortedItems(orderedItems, sources)),
                    "app-3,app-4,app-1,app-2", "notification count ordering");
        sources = [{
            "desktopEntry": "app-4.desktop",
            "appName": "",
            "count": 1
        }, {
            "desktopEntry": "app-2.desktop",
            "appName": "",
            "count": 1
        }];
        expectEqual(itemIds(tray.sortedItems(orderedItems, sources)),
                    "app-2,app-4,app-1,app-3", "ties keep registration order");
        expectEqual(itemIds(tray.sortedItems(orderedItems, [])),
                    "app-1,app-2,app-3,app-4", "clear restores registration order");
        sources = [{
            "desktopEntry": "Unknown.desktop",
            "appName": "Notification",
            "count": 99
        }];
        expectEqual(itemIds(tray.sortedItems(orderedItems, sources)),
                    "app-1,app-2,app-3,app-4", "unknown source is ignored");
        const ambiguousItems = fakeItems(2);
        ambiguousItems[0].title = "Shared";
        ambiguousItems[1].tooltipTitle = "Shared";
        sources = [{
            "desktopEntry": "",
            "appName": "Shared",
            "count": 5
        }];
        expectEqual(tray.notificationCountsForItems(ambiguousItems, sources).join(","),
                    "0,0", "ambiguous source is ignored");
        const ambiguousDesktopItems = fakeItems(2);
        ambiguousDesktopItems[0].id = "org.example.App.desktop";
        ambiguousDesktopItems[1].id = "/opt/org.example.App.desktop";
        sources = [{
            "desktopEntry": "org.example.App.desktop",
            "appName": "Application 1",
            "count": 4
        }];
        expectEqual(tray.notificationCountsForItems(ambiguousDesktopItems, sources).join(","),
                    "0,0", "ambiguous desktop source is ignored");
        sources = [{
            "desktopEntry": "app-3.desktop",
            "appName": "",
            "count": 2
        }, {
            "desktopEntry": "",
            "appName": "Application 3",
            "count": 3
        }];
        expectEqual(tray.notificationCountsForItems(orderedItems, sources)[2], 5,
                    "multiple buckets accumulate on one tray item");
        expectEqual(tray.badgeText(100), "99+", "badge count cap");

        const realItems = [fcitxItem, chromeItem, larkItem, qqItem];
        tray.trayItems = identityModel;
        expectEqual(tray.notificationCountsForItems(realItems, [{
            "desktopEntry": "",
            "appName": "Fcitx",
            "count": 1
        }]).join(","), "1,0,0,0", "Fcitx appName matches exact tray item");
        expectEqual(tray.notificationCountsForItems(realItems, [{
            "desktopEntry": "",
            "appName": "VCP AI 聊天客户端",
            "count": 1
        }]).join(","), "0,1,0,0",
                    "VCP tooltip appName matches exact tray item");
        expectEqual(tray.notificationCountsForItems(realItems, [{
            "desktopEntry": "",
            "appName": "飞书",
            "count": 1
        }]).join(","), "0,0,1,0", "Lark tooltip appName matches exact tray item");
        const historySources = [{
            "desktopEntry": "QQ",
            "appName": "QQ",
            "count": 4
        }, {
            "desktopEntry": "",
            "appName": "Fcitx",
            "count": 2
        }, {
            "desktopEntry": "",
            "appName": "飞书",
            "count": 2
        }, {
            "desktopEntry": "",
            "appName": "VCP AI 聊天客户端",
            "count": 1
        }];
        expectEqual(tray.notificationCountsForItems(realItems, historySources).join(","),
                    "2,1,2,4", "history source counts map QQ without VCP crossover");
        expectEqual(itemIds(tray.sortedItems(realItems, historySources)),
                    "chrome_status_icon_1,Fcitx,lark_status_icon_1,chrome_status_icon_1",
                    "QQ count promotes only blank-label chrome item");
        expectEqual(tray.notificationCountsForItems(realItems, [{
            "desktopEntry": "QQ.desktop",
            "appName": "QQ",
            "count": 3
        }]).join(","), "0,0,0,3",
                    "QQ source maps to fallback item only");
        tray.notificationSourceCounts = historySources;
        expectEqual(tray.notificationCountForItem(larkItem), 2,
                    "QtObject tray item receives history notification count");
        expectEqual(larkDelegate.notificationCount, 2,
                    "TrayItem delegate exposes history notification badge count");
        expectEqual(tray.notificationCountForItem(qqItem), 4,
                    "QQ delegate receives history badge count");
        expectEqual(qqDelegate.notificationCount, 4,
                    "QQ TrayItem delegate exposes history badge count");
        tray.notificationSourceCounts = [];
        expectEqual(itemIds(tray.sortedItems(realItems, [])),
                    "Fcitx,chrome_status_icon_1,lark_status_icon_1,chrome_status_icon_1",
                    "clearing history source counts restores registration order");
        expectEqual(larkDelegate.notificationCount, 0,
                    "clearing history source counts clears TrayItem badge");
        expectEqual(qqDelegate.notificationCount, 0,
                    "clearing history source counts clears QQ badge");
        const duplicateQqItems = [qqItem, {
            "trayId": "chrome_status_icon_1",
            "title": "",
            "tooltipTitle": "",
            "tooltipDescription": ""
        }];
        expectEqual(tray.notificationCountsForItems(duplicateQqItems, [{
            "desktopEntry": "QQ",
            "appName": "QQ",
            "count": 5
        }]).join(","), "0,0",
                    "ambiguous blank-label QQ candidates are ignored");

        const replacementActive = [oldNotification, currentNotification];
        const afterOldClose = TrayModel.removeNotificationByIdentity(
            replacementActive, oldNotification);
        expectEqual(afterOldClose.length, 1,
                    "replacement close removes one object by identity");
        expect(afterOldClose[0] === currentNotification,
               "old replacement close keeps current notification object");
        const afterCurrentClose = TrayModel.removeNotificationByIdentity(
            afterOldClose, currentNotification);
        expectEqual(afterCurrentClose.length, 0,
                    "current replacement close removes itself");

        const oldGroupedNotification = {"id": 700, "appName": "旧应用", "urgency": 1};
        const newGroupedNotification = {"id": 700, "appName": "新应用", "urgency": 1};
        const groupsWithReplacement = [{
            "appName": "旧应用",
            "notifications": [oldGroupedNotification],
            "critical": false
        }, {
            "appName": "新应用",
            "notifications": [newGroupedNotification],
            "critical": false
        }];
        const groupsAfterReplacement = TrayModel.removeReplacedNotificationFromGroups(
            groupsWithReplacement, newGroupedNotification);
        expectEqual(groupsAfterReplacement.length, 1,
                    "replacement removes old app group by notification id");
        expectEqual(groupsAfterReplacement[0].appName, "新应用",
                    "replacement keeps new app group");
        expect(groupsAfterReplacement[0].notifications[0] === newGroupedNotification,
               "replacement keeps current notification object in groups");
        const groupsAfterOldClose = TrayModel.removeNotificationFromGroupsByIdentity(
            groupsAfterReplacement, oldGroupedNotification);
        expectEqual(groupsAfterOldClose[0].notifications.length, 1,
                    "old replacement close keeps new app group");
        const groupsAfterNewClose = TrayModel.removeNotificationFromGroupsByIdentity(
            groupsAfterOldClose, newGroupedNotification);
        expectEqual(groupsAfterNewClose.length, 0,
                    "current replacement close clears new app group");

        tray.directIconLimit = 0;
        setState(6, 1);
        expectEqual(tray.collapsedSlots, 1, "collapsed tray keeps one composite slot");
        expectEqual(tray.implicitWidth, Config.BarTuning.trayCompositeWidth, "collapsed tray configured width");
        tray.directIconLimit = 3;
        tray.trayItems = lateIdentityModel;
        tray.notificationSourceCounts = [{
            "desktopEntry": "",
            "appName": "Late Application",
            "count": 1
        }];
        const revisionBeforeIdentity = tray.modelRevision;
        lateItem.title = "Late Application";
        expect(tray.modelRevision > revisionBeforeIdentity,
               "late tray identity change bumps model revision");
        expectEqual(tray.notificationCountForItem(lateItem), 1,
                    "late tray identity is rematched");
        if (failureCount === 0) {
            console.log("[TrayStateCheck] PASS");
            Qt.exit(0);
        } else {
            console.error("[TrayStateCheck] FAIL count=" + failureCount);
            Qt.exit(1);
        }
    }

    TrayIsland {
        id: tray

        height: Config.BarTuning.islandHeight
        trayItems: []
    }

    QtObject {
        id: identityModel
        property var values: [fcitxItem, chromeItem, larkItem, qqItem]
    }

    QtObject {
        id: lateIdentityModel
        property var values: [lateItem]
    }

    QtObject {
        id: oldNotification
    }

    QtObject {
        id: currentNotification
    }

    QtObject {
        id: fcitxItem
        property string trayId: "Fcitx"
        property string title: "Fcitx"
        property string tooltipTitle: "Fcitx"
        property string icon: ""
        property bool hasMenu: false
        property var menu: null

        function activate() {
        }
    }

    QtObject {
        id: chromeItem
        property string trayId: "chrome_status_icon_1"
        property string title: "Chrome"
        property string tooltipTitle: "VCP AI 聊天客户端"
        property string icon: ""
        property bool hasMenu: false
        property var menu: null

        function activate() {
        }
    }

    QtObject {
        id: larkItem
        property string trayId: "lark_status_icon_1"
        property string title: "Lark"
        property string tooltipTitle: "飞书"
        property string icon: ""
        property bool hasMenu: false
        property var menu: null

        function activate() {
        }
    }

    QtObject {
        id: qqItem
        property string trayId: "chrome_status_icon_1"
        property string title: ""
        property string tooltipTitle: ""
        property string tooltipDescription: ""
        property string icon: ""
        property bool hasMenu: false
        property var menu: null

        function activate() {
        }
    }

    TrayItem {
        id: larkDelegate
        trayItem: larkItem
        notificationCount: tray.notificationCountForItem(larkItem)
        shown: true
    }

    TrayItem {
        id: qqDelegate
        trayItem: qqItem
        notificationCount: tray.notificationCountForItem(qqItem)
        shown: true
    }

    QtObject {
        id: lateItem
        property string title: "Late Placeholder"
        property string tooltipTitle: "Late Placeholder"
        property string icon: ""
        property bool hasMenu: false
        property var menu: null

        function activate() {
        }
    }

    Timer {
        interval: 0
        running: true
        onTriggered: Qt.callLater(testRoot.runChecks)
    }

}
