import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "vendor/brain/services"

ShellRoot {
    id: test

    property int failures: 0
    property var originalCells: []
    property bool receivedDuringAnimation: false
    property real progress: 0
    property real maximumFrameMs: 0
    property int frameCount: 0

    function expect(condition, message) {
        if (!condition) {
            failures += 1
            console.error("[CalendarColdStart] 失败：" + message)
        }
    }

    function cellsIn(item) {
        var result = []
        for (var i = 0; i < item.children.length; ++i) {
            var child = item.children[i]
            if ("dateKey" in child && "isToday" in child)
                result.push(child)
            else
                result = result.concat(cellsIn(child))
        }
        return result
    }

    function expectStableCells(label) {
        var current = cellsIn(calendar)
        var reused = 0
        for (var i = 0; i < current.length; ++i) {
            if (current[i] === originalCells[i])
                reused += 1
        }
        expect(current.length === 42 && reused === 42,
               label + "：日期单元应全部复用，实际 " + reused + "/42")
    }

    function verifyHolidayUpdates(today, key) {
        var payload = JSON.stringify({ year: today.getFullYear(), days: [
            { date: key, name: "测试休息日", isOffDay: true }
        ] })
        var revision = HolidayService.revision
        expect(HolidayService._applyPayload(today.getFullYear(), payload), "相同数据应正常接收")
        expect(HolidayService.revision === revision, "相同节假日数据不应触发刷新")
        expectStableCells("重复数据返回")

        calendar.selectedDate = key
        payload = JSON.stringify({ year: today.getFullYear(), days: [
            { date: key, name: "测试调休", isOffDay: false }
        ] })
        expect(HolidayService._applyPayload(today.getFullYear(), payload), "调休变更应接收")
        expect(calendar._todayStatus.kind === "makeup", "调休状态应实时更新")
        expect(calendar.selectedDate === key, "数据刷新不应清除日期选择")
        expectStableCells("节假日变更")

        var began = Date.now()
        for (var i = 0; i < 20; ++i) {
            HolidayService._applyPayload(today.getFullYear(), JSON.stringify({
                year: today.getFullYear(), days: [
                    { date: key, name: "测试更新 " + i, isOffDay: i % 2 === 0 }
                ]
            }))
        }
        console.log("[CalendarColdStart] 20 次实际数据变更同步耗时=" + (Date.now() - began) + "ms")
        expectStableCells("连续数据变更")
    }

    function verifyNavigation(today, key) {
        calendar._year = 2028
        calendar._month = 1
        calendar._rebuild()
        expect(calendar._days.filter(day => day.cur).length === 29, "闰年二月应有 29 天")
        expectStableCells("切换月份")
        calendar._month = 11
        calendar._next()
        expect(calendar._year === 2029 && calendar._month === 0, "跨年下一月")
        calendar._prev()
        expect(calendar._year === 2028 && calendar._month === 11, "跨年上一月")
        expectStableCells("跨年切换")

        var previous = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 1)
        calendar._todayYear = previous.getFullYear()
        calendar._todayMonth = previous.getMonth()
        calendar._todayDay = previous.getDate()
        calendar._year = previous.getFullYear()
        calendar._month = previous.getMonth()
        calendar.selectedDate = key
        expect(calendar._syncToday(), "午夜或唤醒后应同步当前日期")
        expect(calendar._year === today.getFullYear() && calendar._month === today.getMonth(),
               "当前月应随日期更新")
        expect(calendar.selectedDate === key, "午夜同步应保留选择")
        expectStableCells("午夜同步")
    }

    function verifyCalendar() {
        expect(receivedDuringAnimation, "冷启动数据应在展开动画中途到达")
        expectStableCells("首次数据返回")
        var today = new Date()
        var key = calendar._dateKeyFor(today.getFullYear(), today.getMonth(), today.getDate())
        var todayCell = cellsIn(calendar).find(cell => cell.dateKey === key)
        expect(todayCell && todayCell.dayStatus.kind === "holiday", "首次返回的节假日应生效")
        expect(todayCell && todayCell.isToday, "当前日期高亮应保持")
        verifyHolidayUpdates(today, key)
        verifyDeferredUpdates(today, key)
        verifyNavigation(today, key)

        console.log("[CalendarColdStart] 动画帧数=" + frameCount
                    + " 最大帧间隔=" + maximumFrameMs.toFixed(1) + "ms")
        console.log("[CalendarColdStart] " + (failures === 0 ? "通过" : "失败 " + failures + " 项"))
        Qt.exit(failures === 0 ? 0 : 1)
    }

    function verifyDeferredUpdates(today, key) {
        calendar.deferUpdates = true
        var displayed = calendar._todayStatus
        for (var i = 0; i < 3; ++i) {
            HolidayService._applyPayload(today.getFullYear(), JSON.stringify({
                year: today.getFullYear(), days: [
                    { date: key, name: "延后更新 " + i, isOffDay: i % 2 === 0 }
                ]
            }))
        }
        expect(calendar._todayStatus === displayed, "动画中多次返回应保留已显示的数据")
        expect(calendar._holidayRefreshPending, "应记录待显示的节假日更新")
        calendar.deferUpdates = false
        calendar.deferUpdates = true
        calendar._flushHolidayRefresh()
        expect(calendar._todayStatus === displayed, "动画反向后不应误刷待显示数据")
        calendar.deferUpdates = false
        calendar._flushHolidayRefresh()
        expect(calendar._todayStatus.name === "延后更新 2", "结束过渡后只应用最新状态")
        expect(!calendar._holidayRefreshPending, "显示完成应清除待更新标记")
        expectStableCells("过渡后显示数据")
    }

    Window {
        visible: true
        width: 240
        height: 400
        color: "#101416"
        flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus

        CalendarCard {
            id: calendar
            anchors.fill: parent
            anchors.margins: 12
            opacity: 0.2 + 0.8 * test.progress
            deferUpdates: opening.running
        }

        FrameAnimation {
            running: opening.running
            onTriggered: {
                test.frameCount += 1
                test.maximumFrameMs = Math.max(test.maximumFrameMs, frameTime * 1000)
            }
        }
    }

    NumberAnimation {
        id: opening
        target: test
        property: "progress"
        from: 0
        to: 1
        duration: 280
        easing.type: Easing.OutQuad
        onFinished: finishTimer.start()
    }

    Timer { id: finishTimer; interval: 32; onTriggered: test.verifyCalendar() }

    // 假下载器等此标记后延迟返回，确保覆盖动画中途的首次数据填充。
    Process {
        id: releaseData
        command: ["sh", "-c", "sleep 0.08; printf ready > \"$HOME/release-holidays\""]
    }

    Connections {
        target: HolidayService
        function onRevisionChanged() {
            if (opening.running) {
                test.receivedDuringAnimation = true
                console.log("[CalendarColdStart] 首次数据到达进度=" + test.progress.toFixed(3))
                Qt.callLater(function() {
                    test.expect(calendar._holidayRefreshPending, "动画中返回的数据应等待显示")
                    test.expect(calendar._todayStatus.kind !== "holiday", "动画中不能提前更新日期视图")
                    test.expectStableCells("展开中数据返回")
                })
            }
        }
    }

    Timer {
        interval: 400
        running: true
        onTriggered: {
            test.expect(HolidayService.revision === 0, "开始时不能已有节假日缓存")
            test.originalCells = test.cellsIn(calendar)
            test.expect(test.originalCells.length === 42, "初始网格应包含 42 个日期单元")
            opening.start()
            releaseData.running = true
        }
    }

    Timer {
        interval: 5000
        running: true
        onTriggered: {
            console.error("[CalendarColdStart] 超时")
            Qt.exit(1)
        }
    }
}
