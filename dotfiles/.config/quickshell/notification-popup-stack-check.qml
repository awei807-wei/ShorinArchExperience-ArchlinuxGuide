import QtQuick
import Quickshell
import "components"

// 临时通知浮层卡片栈的回归门禁：分组数组整体替换时，已有卡片必须被复用
// 而不是销毁重建；消失的分组先播放退场，播完后才销毁；同应用新通知在旧卡片
// 退场期间另起一张卡片。
ShellRoot {
    id: testRoot

    property int failureCount: 0
    property int phase: 0
    property var cardA: null
    property var cardB: null

    function expect(condition, label) {
        if (condition)
            return
        failureCount += 1
        console.error("[NotificationPopupStackCheck] failed: " + label)
    }

    function makeNotification(id, urgency) {
        return {
            "id": id,
            "summary": "Notification " + id,
            "body": "",
            "appName": "",
            "desktopEntry": "",
            "appIcon": "",
            "urgency": urgency === undefined ? 1 : urgency,
            "actions": [],
            "resident": false,
            "expire": function() {},
            "dismiss": function() {}
        }
    }

    function group(appName, notifications) {
        return {
            "appName": appName,
            "notifications": notifications,
            "critical": false
        }
    }

    function finish() {
        if (failureCount === 0) {
            console.log("[NotificationPopupStackCheck] PASS")
            Qt.exit(0)
        } else {
            console.error("[NotificationPopupStackCheck] FAIL count=" + failureCount)
            Qt.exit(1)
        }
    }

    // Column 等定位器依赖窗口的 polish 才会布局，因此放进真实（离屏）窗口
    FloatingWindow {
        id: hostWindow

        implicitWidth: 400
        implicitHeight: 1200
        visible: true
        color: "transparent"

        NotificationPopupStack {
            id: stack

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            unit: 13.6
            groups: []
        }
    }

    Timer {
        id: phaseTimer

        onTriggered: {
            if (testRoot.phase === 0) {
                stack.groups = [
                    testRoot.group("Alpha", [testRoot.makeNotification(1)]),
                    testRoot.group("Beta", [testRoot.makeNotification(2)])
                ]
                testRoot.cardA = stack.cardFor("Alpha")
                testRoot.cardB = stack.cardFor("Beta")
                expect(stack.createdCount === 2 && stack.liveCardCount() === 2,
                       "two groups create two cards")
                expect(testRoot.cardA !== null && testRoot.cardB !== null,
                       "cards are addressable by app key")
                testRoot.phase = 1
                phaseTimer.interval = 30
                phaseTimer.restart()
                return
            }

            if (testRoot.phase === 1) {
                // Column 高度在一次布局后才可用，宿主窗口据此裁定输入区域
                expect(stack.columnHeight > 0, "column reports card height")
                // 同应用追加通知：数组整体替换，但 Alpha 卡片必须原地更新
                stack.groups = [
                    testRoot.group("Alpha", [testRoot.makeNotification(1),
                                             testRoot.makeNotification(3)]),
                    testRoot.group("Beta", [testRoot.makeNotification(2)])
                ]
                expect(stack.createdCount === 2,
                       "updating a group does not recreate cards")
                expect(stack.cardFor("Alpha") === testRoot.cardA,
                       "same card instance keeps serving Alpha")
                expect(testRoot.cardA.notifications.length === 2,
                       "card sees the appended notification")
                testRoot.phase = 2
                phaseTimer.interval = 30
                phaseTimer.restart()
                return
            }

            if (testRoot.phase === 2) {
                // 删除 Beta：Alpha 不重建，Beta 先退场再销毁
                stack.groups = [
                    testRoot.group("Alpha", [testRoot.makeNotification(1),
                                             testRoot.makeNotification(3)])
                ]
                expect(stack.createdCount === 2,
                       "removing a group creates no new cards")
                expect(stack.cardFor("Alpha") === testRoot.cardA,
                       "surviving card is untouched")
                expect(testRoot.cardB.exiting,
                       "removed group starts its exit animation")
                expect(stack.destroyedCount === 0,
                       "exiting card is not destroyed synchronously")
                expect(stack.liveCardCount() === 1,
                       "live card count excludes exiting card")
                testRoot.phase = 3
                phaseTimer.interval = 40
                phaseTimer.restart()
                return
            }

            if (testRoot.phase === 3) {
                // 退场期间同应用再次出现：另起新卡片，旧卡片继续退场
                stack.groups = [
                    testRoot.group("Alpha", [testRoot.makeNotification(1),
                                             testRoot.makeNotification(3)]),
                    testRoot.group("Beta", [testRoot.makeNotification(4)])
                ]
                expect(stack.createdCount === 3,
                       "re-notifying during exit creates a fresh card")
                expect(stack.cardFor("Beta") !== testRoot.cardB
                       && stack.cardFor("Beta") !== null,
                       "fresh card replaces the exiting one in the map")
                testRoot.phase = 4
                phaseTimer.interval = 450
                phaseTimer.restart()
                return
            }

            if (testRoot.phase === 4) {
                expect(stack.destroyedCount === 1,
                       "exited card is destroyed after its animation")
                expect(stack.liveCardCount() === 2,
                       "two live cards remain after exit completes")
                stack.groups = []
                testRoot.phase = 5
                phaseTimer.interval = 450
                phaseTimer.restart()
                return
            }

            if (testRoot.phase === 5) {
                expect(stack.destroyedCount === 3,
                       "clearing all groups destroys remaining cards after exit")
                expect(stack.liveCardCount() === 0
                       && stack.columnHeight === 0,
                       "empty stack collapses to zero height")
                finish()
            }
        }
    }

    Component.onCompleted: {
        phase = 0
        phaseTimer.interval = 0
        phaseTimer.restart()
    }
}
