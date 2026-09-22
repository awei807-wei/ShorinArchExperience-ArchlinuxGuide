import QtQuick
import "../../"
import "../"
import "../../components"
import "../../../../config" as Config

// Calendar card — month grid with shared Chinese statutory holiday data.
StatCard {
    id: root
    padding: 0

    property string selectedDate: ""
    signal dateSelectionRequested(string dateKey)

    // ── State ─────────────────────────────────────────────────────────────────
    property int _year: 0
    property int _month: 0
    property int _todayYear: 0
    property int _todayMonth: 0
    property int _todayDay: 0
    property var _days: []
    property string _label: ""
    property var _todayStatus: ({
        dateKey: "",
        isOffDay: false,
        isWork: true,
        label: "",
        name: "",
        kind: "workday"
    })

    readonly property var _monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    readonly property var _dowNames: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    Component.onCompleted: {
        var now = new Date()
        root._todayYear = now.getFullYear()
        root._todayMonth = now.getMonth()
        root._todayDay = now.getDate()
        root._year = root._todayYear
        root._month = root._todayMonth
        HolidayService.ensureYear(root._todayYear)
        root._refreshTodayStatus()
        root._rebuild()
        root._scheduleMidnight()
    }

    function _zp2(number) {
        return number < 10 ? "0" + number : "" + number
    }

    function _dateKeyFor(year, monthZeroBased, day) {
        return year + "-" + root._zp2(monthZeroBased + 1) + "-" + root._zp2(day)
    }

    function _refreshTodayStatus() {
        root._todayStatus = HolidayService.getDayStatus(
            root._todayYear,
            root._todayMonth,
            root._todayDay
        )
    }

    function _makeupName(name) {
        var value = name === null || name === undefined ? "" : String(name)
        if (value === "")
            return "调休"
        return value.indexOf("调休") === -1 ? value + "调休" : value
    }

    function _todaySummary() {
        var status = root._todayStatus || ({ kind: "workday", name: "" })
        if (status.kind === "holiday")
            return "今天 · " + (status.name || "法定节假日") + " · 休息日"
        if (status.kind === "makeup")
            return "今天 · " + root._makeupName(status.name) + " · 工作日"
        if (status.kind === "weekend")
            return "今天 · 周末 · 休息日"
        return "今天 · 工作日"
    }

    function _todaySummaryColor() {
        var kind = root._todayStatus ? root._todayStatus.kind : "workday"
        if (kind === "holiday")
            return Config.Theme.danger
        if (kind === "makeup")
            return Config.Theme.accentTertiary
        return Config.Theme.textMuted
    }

    function _rebuild() {
        root._label = root._monthNames[root._month].substring(0, 3).toUpperCase()
            + "  " + root._year

        var firstDow = new Date(root._year, root._month, 1).getDay()
        var daysInMonth = new Date(root._year, root._month + 1, 0).getDate()
        var daysInPreviousMonth = new Date(root._year, root._month, 0).getDate()
        var days = []

        for (var previous = firstDow - 1; previous >= 0; --previous) {
            days.push({
                n: daysInPreviousMonth - previous,
                cur: false,
                dateKey: "",
                dayStatus: null
            })
        }

        for (var day = 1; day <= daysInMonth; ++day) {
            var dateKey = root._dateKeyFor(root._year, root._month, day)
            days.push({
                n: day,
                cur: true,
                dateKey: dateKey,
                dayStatus: HolidayService.getDayStatus(root._year, root._month, day)
            })
        }

        var tail = 42 - days.length
        for (var next = 1; next <= tail; ++next) {
            days.push({
                n: next,
                cur: false,
                dateKey: "",
                dayStatus: null
            })
        }
        root._days = days
    }

    function _prev() {
        if (root.selectedDate !== "")
            root.dateSelectionRequested("")

        var previousYear = root._year
        if (root._month === 0) {
            root._month = 11
            root._year -= 1
        } else {
            root._month -= 1
        }
        if (root._year !== previousYear)
            HolidayService.ensureYear(root._year)
        root._rebuild()
    }

    function _next() {
        if (root.selectedDate !== "")
            root.dateSelectionRequested("")

        var previousYear = root._year
        if (root._month === 11) {
            root._month = 0
            root._year += 1
        } else {
            root._month += 1
        }
        if (root._year !== previousYear)
            HolidayService.ensureYear(root._year)
        root._rebuild()
    }

    function _toggleDateSelection(dateKey) {
        if (dateKey === "")
            return
        root.dateSelectionRequested(root.selectedDate === dateKey ? "" : dateKey)
    }

    function _hasOpenTask(dateKey) {
        if (dateKey === "")
            return false
        var tasks = TaskService.tasks || []
        for (var i = 0; i < tasks.length; ++i) {
            var dueDate = tasks[i].dueDate || ""
            if (tasks[i].column !== 2 && dueDate.length >= 10
                    && dueDate.substring(0, 10) === dateKey)
                return true
        }
        return false
    }

    function _scheduleMidnight() {
        var now = new Date()
        var nextMidnight = new Date(
            now.getFullYear(),
            now.getMonth(),
            now.getDate() + 1,
            0, 0, 0, 75
        )
        midnightTimer.interval = Math.max(1000, nextMidnight.getTime() - now.getTime())
        midnightTimer.restart()
    }

    function _handleMidnight() {
        var wasViewingCurrentMonth = root._year === root._todayYear
            && root._month === root._todayMonth
        var now = new Date()
        var nextTodayYear = now.getFullYear()
        var nextTodayMonth = now.getMonth()
        var nextTodayDay = now.getDate()

        root._todayYear = nextTodayYear
        root._todayMonth = nextTodayMonth
        root._todayDay = nextTodayDay
        HolidayService.ensureYear(nextTodayYear)
        root._refreshTodayStatus()

        if (wasViewingCurrentMonth
                && (root._year !== nextTodayYear || root._month !== nextTodayMonth)) {
            root._year = nextTodayYear
            root._month = nextTodayMonth
        }

        root._rebuild()
        root._scheduleMidnight()
    }

    Connections {
        target: HolidayService
        function onRevisionChanged() {
            root._refreshTodayStatus()
            root._rebuild()
        }
    }

    Timer {
        id: midnightTimer
        repeat: false
        onTriggered: root._handleMidnight()
    }

    // ── UI ────────────────────────────────────────────────────────────────────
    Item {
        anchors { fill: parent; margins: 12 }

        // Header: month navigation plus a restrained current-day status line.
        Item {
            id: hdr
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 34

            Item {
                id: monthRow
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 18

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: "‹"
                    font.pixelSize: 15
                    color: pH.hovered ? Qt.rgba(1, 1, 1, 0.7) : Qt.rgba(1, 1, 1, 0.25)
                    Behavior on color { ColorAnimation { duration: 100 } }
                    HoverHandler { id: pH; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: root._prev() }
                }

                Text {
                    anchors.centerIn: parent
                    text: root._label
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: Theme.text
                }

                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: "›"
                    font.pixelSize: 15
                    color: nH.hovered ? Qt.rgba(1, 1, 1, 0.7) : Qt.rgba(1, 1, 1, 0.25)
                    Behavior on color { ColorAnimation { duration: 100 } }
                    HoverHandler { id: nH; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: root._next() }
                }
            }

            Text {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: monthRow.bottom
                    topMargin: 1
                }
                height: 13
                text: root._todaySummary()
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                font.pixelSize: 8
                color: root._todaySummaryColor()
            }
        }

        // DOW row
        Item {
            id: dow
            anchors { left: parent.left; right: parent.right; top: hdr.bottom; topMargin: 2 }
            height: 14

            Row {
                anchors.fill: parent
                Repeater {
                    model: root._dowNames
                    delegate: Text {
                        width: Math.floor(dow.width / 7)
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        font.pixelSize: 8
                        font.weight: Font.Bold
                        color: Qt.rgba(1, 1, 1, 0.2)
                    }
                }
            }
        }

        // Day grid
        Grid {
            id: grid
            anchors {
                left: parent.left
                right: parent.right
                top: dow.bottom
                topMargin: 2
                bottom: parent.bottom
            }
            columns: 7
            rows: 6

            readonly property real cW: width / 7
            readonly property real cH: height / 6

            Repeater {
                model: root._days
                delegate: Item {
                    id: dayCell
                    required property var modelData
                    required property int index
                    width: grid.cW
                    height: grid.cH

                    readonly property bool isToday: modelData.cur
                        && modelData.n === root._todayDay
                        && root._month === root._todayMonth
                        && root._year === root._todayYear
                    readonly property string dateKey: modelData.cur ? modelData.dateKey : ""
                    readonly property bool isSelected: modelData.cur
                        && dayCell.dateKey === root.selectedDate
                    readonly property bool hasOpenTask: modelData.cur
                        && root._hasOpenTask(dayCell.dateKey)
                    readonly property var dayStatus: modelData.cur ? modelData.dayStatus : null
                    readonly property bool showHolidayBadge: dayCell.dayStatus
                        && (dayCell.dayStatus.kind === "holiday"
                            || dayCell.dayStatus.kind === "makeup")
                    readonly property color badgeTone: dayCell.dayStatus
                        && dayCell.dayStatus.kind === "holiday"
                        ? Config.Theme.danger : Config.Theme.accentTertiary

                    Rectangle {
                        id: dayCircle
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 4
                        height: width
                        radius: width / 2
                        color: dayCell.isSelected ? Theme.active
                            : dayCell.isToday ? Qt.rgba(166 / 255, 208 / 255, 247 / 255, 0.15)
                            : dH.hovered && modelData.cur ? Qt.rgba(1, 1, 1, 0.07)
                            : "transparent"
                        border.color: dayCell.isToday
                            ? (dayCell.isSelected
                                ? Theme.background
                                : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35))
                            : "transparent"
                        border.width: dayCell.isToday ? 1 : 0
                        Behavior on color { ColorAnimation { duration: 80 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.n
                            font.pixelSize: 9
                            font.family: "JetBrains Mono"
                            font.weight: dayCell.isSelected || dayCell.isToday
                                ? Font.Bold : Font.Normal
                            color: dayCell.isSelected ? Theme.background
                                : dayCell.isToday ? Theme.active
                                : modelData.cur ? Qt.rgba(205 / 255, 214 / 255, 244 / 255, 0.55)
                                : Qt.rgba(1, 1, 1, 0.13)
                        }

                        Rectangle {
                            visible: dayCell.showHolidayBadge
                            anchors {
                                right: parent.right
                                top: parent.top
                                rightMargin: -2
                                topMargin: -2
                            }
                            width: 12
                            height: 10
                            radius: 3
                            color: dayCell.isSelected
                                ? Config.Theme.surfaceContainer
                                : Qt.rgba(
                                    dayCell.badgeTone.r,
                                    dayCell.badgeTone.g,
                                    dayCell.badgeTone.b,
                                    0.24
                                )
                            border.color: dayCell.isSelected
                                ? dayCell.badgeTone : "transparent"
                            border.width: dayCell.isSelected ? 1 : 0

                            Text {
                                anchors.centerIn: parent
                                text: dayCell.dayStatus ? dayCell.dayStatus.label : ""
                                font.pixelSize: 7
                                font.weight: Font.Bold
                                color: dayCell.isSelected ? Config.Theme.textPrimary
                                    : dayCell.dayStatus && dayCell.dayStatus.kind === "holiday"
                                        ? Config.Theme.danger : Config.Theme.textMuted
                            }
                        }

                        Rectangle {
                            visible: dayCell.hasOpenTask
                            anchors {
                                horizontalCenter: parent.horizontalCenter
                                bottom: parent.bottom
                                bottomMargin: 1
                            }
                            width: 3
                            height: 3
                            radius: 1.5
                            color: dayCell.isSelected ? Theme.background : Theme.active
                        }
                    }

                    HoverHandler {
                        id: dH
                        enabled: modelData.cur
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        enabled: modelData.cur
                        acceptedButtons: Qt.LeftButton
                        onTapped: root._toggleDateSelection(dayCell.dateKey)
                    }
                }
            }
        }
    }
}
