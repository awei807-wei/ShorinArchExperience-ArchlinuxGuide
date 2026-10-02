import QtQuick
import Quickshell
import Quickshell.Io
import "components"
import "vendor/brain/services"

ShellRoot {
    id: test

    property int failures: 0
    property int pass: 0
    property var calendar: null
    property bool receivedDuringAnimation: false
    property bool sampling: false
    property real maximumFrameMs: 0
    property int frames: 0

    function expect(condition, message) {
        if (condition)
            return
        failures += 1
        console.error("[CenterColdStart] 失败：" + message)
    }

    function findCalendar(item) {
        if ("_days" in item && "deferUpdates" in item)
            return item
        for (var i = 0; i < item.children.length; ++i) {
            var found = findCalendar(item.children[i])
            if (found)
                return found
        }
        return null
    }

    function startOpening() {
        maximumFrameMs = 0
        frames = 0
        sampling = true
        controller.togglePage("home")
    }

    function verifyOpened() {
        expect(calendar && !calendar.deferUpdates, "展开完成后应恢复日历更新")
        expect(calendar && !calendar._holidayRefreshPending, "展开完成后应提交待显示数据")
        expect(receivedDuringAnimation, "应覆盖首次数据在动画中途返回")
        console.log("[CenterColdStart] " + (pass === 0 ? "首次" : "再次")
                    + "展开：帧数=" + frames + " 最大帧=" + maximumFrameMs.toFixed(1) + "ms")
        if (pass === 0) {
            expect(calendar && calendar._todayStatus.kind === "holiday", "展开后应显示节假日")
            var screenshot = Quickshell.env("CALENDAR_CHECK_SCREENSHOT")
            if (screenshot)
                dashboard.contentItem.children[0].grabToImage(result => {
                    test.expect(result.saveToFile(screenshot), "应保存测试截图")
                })
            pass = 1
            closeTimer.start()
        } else {
            expect(calendar && calendar._todayStatus.name === "关闭期间更新", "再次打开应显示最新数据")
            console.log("[CenterColdStart] " + (failures === 0 ? "通过" : "失败 " + failures + " 项"))
            Qt.exit(failures === 0 ? 0 : 1)
        }
    }

    CenterPanelController { id: controller }
    CenterDashboard {
        id: dashboard
        controller: controller
        modelData: Quickshell.screens[0]
    }

    FrameAnimation {
        running: test.sampling
        onTriggered: {
            test.frames += 1
            test.maximumFrameMs = Math.max(test.maximumFrameMs, frameTime * 1000)
        }
    }

    Process {
        id: releaseData
        command: ["sh", "-c", "sleep 0.08; printf ready > \"$HOME/release-holidays\""]
    }

    Connections {
        target: controller
        function onCenterPanelProgressChanged() {
            if (controller.centerPanelProgress < 1)
                return
            test.sampling = false
            settledTimer.start()
        }
    }

    Connections {
        target: HolidayService
        function onRevisionChanged() {
            if (test.pass === 0 && controller.open && controller.centerPanelProgress < 1) {
                test.receivedDuringAnimation = true
                Qt.callLater(function() {
                    test.expect(test.calendar.deferUpdates, "宿主应暂停动画中的日历更新")
                    test.expect(test.calendar._holidayRefreshPending, "首次数据应等待动画结束")
                    test.expect(test.calendar._todayStatus.kind !== "holiday", "动画中应保留原显示")
                })
            }
        }
    }

    Timer {
        interval: 1700
        running: true
        onTriggered: {
            test.calendar = test.findCalendar(dashboard.contentItem)
            test.expect(test.calendar !== null, "应创建 Home 日历")
            test.expect(HolidayService.revision === 0, "首次展开前没有节假日缓存")
            test.startOpening()
            releaseData.running = true
        }
    }

    Timer { id: settledTimer; interval: 40; onTriggered: test.verifyOpened() }
    Timer {
        id: closeTimer
        interval: 400
        onTriggered: {
            controller.close()
            closingUpdate.start()
            reopenTimer.start()
        }
    }
    Timer {
        id: closingUpdate
        interval: 50
        onTriggered: {
            var date = new Date()
            var key = test.calendar._dateKeyFor(date.getFullYear(), date.getMonth(), date.getDate())
            HolidayService._applyPayload(date.getFullYear(), JSON.stringify({
                year: date.getFullYear(), days: [
                    { date: key, name: "关闭期间更新", isOffDay: false }
                ]
            }))
            test.expect(test.calendar.deferUpdates && test.calendar._holidayRefreshPending,
                        "收起动画也应延后日历更新")
        }
    }
    Timer {
        id: reopenTimer
        interval: 500
        onTriggered: {
            test.expect(test.calendar._todayStatus.name === "关闭期间更新", "关闭完成后应同步最新数据")
            test.startOpening()
        }
    }
    Timer {
        running: true
        interval: 6000
        onTriggered: {
            console.error("[CenterColdStart] 超时")
            Qt.exit(1)
        }
    }
}
