import QtQuick
import Quickshell
import "vendor/brain/services"

ShellRoot {
    id: root

    CalendarCard {
        id: calendar
        width: 210
        height: 400
    }

    Timer {
        interval: 500
        running: true
        repeat: false
        onTriggered: {
            var now = new Date()
            var year = now.getFullYear()
            var month = now.getMonth()
            var day = now.getDate()
            var coldStartCorrect = calendar._hasToday
                && calendar._todayYear === year
                && calendar._todayMonth === month
                && calendar._todayDay === day
                && calendar._year === year
                && calendar._month === month

            var previousDate = new Date(year, month, day - 1)
            var previousKey = calendar._dateKeyFor(
                previousDate.getFullYear(),
                previousDate.getMonth(),
                previousDate.getDate()
            )
            var todayKey = calendar._dateKeyFor(year, month, day)

            calendar.selectedDate = previousKey
            calendar._todayYear = previousDate.getFullYear()
            calendar._todayMonth = previousDate.getMonth()
            calendar._todayDay = previousDate.getDate()
            calendar._hasToday = true
            calendar._year = year
            calendar._month = month
            var changed = calendar._syncToday()

            var todayEntry = false
            for (var i = 0; i < calendar._days.length; ++i) {
                var entry = calendar._days[i]
                if (entry.cur && entry.dateKey === todayKey) {
                    todayEntry = true
                    break
                }
            }

            var selectedPreserved = calendar.selectedDate === previousKey
            var currentDateCorrect = calendar._todayYear === year
                && calendar._todayMonth === month
                && calendar._todayDay === day
            var currentViewCorrect = calendar._year === year
                && calendar._month === month

            console.log("[CalendarDateCheck] coldStart=" + coldStartCorrect
                        + " changed=" + changed
                        + " today=" + calendar._todayYear + "-"
                        + (calendar._todayMonth + 1) + "-" + calendar._todayDay
                        + " view=" + calendar._year + "-" + (calendar._month + 1)
                        + " todayEntry=" + todayEntry
                        + " selectedPreserved=" + selectedPreserved)

            var passed = coldStartCorrect && changed && currentDateCorrect
                && currentViewCorrect && todayEntry && selectedPreserved
            Qt.exit(passed ? 0 : 1)
        }
    }
}