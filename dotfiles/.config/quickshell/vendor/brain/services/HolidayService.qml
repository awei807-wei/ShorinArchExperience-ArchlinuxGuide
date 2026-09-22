pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Process-wide holiday store shared by every screen/dashboard instance.
QtObject {
    id: root

    property int revision: 0

    readonly property string _homeDir: {
        var home = Quickshell.env("HOME")
        if (home === null || home === undefined || home === "")
            return "/home/shiyi"
        return String(home)
    }
    readonly property string _scriptPath: root._homeDir + "/.config/scripts/quickshell-holidays.sh"
    readonly property int _startupYear: new Date().getFullYear()

    property var _daysByYear: ({})
    property var _loadedYears: ({})
    property var _requestKeys: ({})
    property var _queue: []
    property var _activeRequest: null
    property string _activeOutput: ""

    function _normaliseYear(value) {
        var year = Number(value)
        if (!isFinite(year) || Math.floor(year) !== year || year < 1000 || year > 9999)
            return 0
        return year
    }

    function _pad2(value) {
        return value < 10 ? "0" + value : "" + value
    }

    function _dateKey(year, monthZeroBased, day) {
        return year + "-" + root._pad2(monthZeroBased + 1) + "-" + root._pad2(day)
    }

    function ensureYear(year) {
        var safeYear = root._normaliseYear(year)
        if (safeYear === 0 || root._loadedYears[String(safeYear)] === true)
            return
        root._enqueue("load", safeYear)
    }

    function _enqueue(mode, year) {
        var safeYear = root._normaliseYear(year)
        if (safeYear === 0 || (mode !== "load" && mode !== "refresh"))
            return

        var key = mode + ":" + safeYear
        if (root._requestKeys[key] === true)
            return

        root._requestKeys[key] = true
        var nextQueue = root._queue.slice()
        nextQueue.push({ mode: mode, year: safeYear, key: key })
        root._queue = nextQueue
        root._startNext()
    }

    function _startNext() {
        if (root._activeRequest !== null || root._process.running || root._queue.length === 0)
            return

        var request = root._queue[0]
        root._queue = root._queue.slice(1)
        root._activeRequest = request
        root._activeOutput = ""
        root._process.command = [root._scriptPath, request.mode, String(request.year)]
        root._process.running = true
    }

    function _copyObject(source) {
        var copy = ({})
        for (var key in source)
            copy[key] = source[key]
        return copy
    }

    function _applyPayload(expectedYear, text) {
        try {
            var payload = JSON.parse(text)
            if (!payload || Number(payload.year) !== expectedYear || !Array.isArray(payload.days))
                throw new Error("unexpected holiday payload")

            var dateMap = ({})
            for (var i = 0; i < payload.days.length; ++i) {
                var entry = payload.days[i]
                if (!entry || typeof entry.date !== "string"
                        || typeof entry.name !== "string"
                        || typeof entry.isOffDay !== "boolean")
                    throw new Error("invalid holiday day entry")
                dateMap[entry.date] = {
                    name: entry.name,
                    isOffDay: entry.isOffDay
                }
            }

            var nextYears = root._copyObject(root._daysByYear)
            nextYears[String(expectedYear)] = dateMap
            root._daysByYear = nextYears

            var nextLoaded = root._copyObject(root._loadedYears)
            nextLoaded[String(expectedYear)] = true
            root._loadedYears = nextLoaded

            root.revision += 1
            return true
        } catch (error) {
            console.warn("HolidayService: invalid holiday JSON:", error)
            return false
        }
    }

    function _finishRequest() {
        var request = root._activeRequest
        if (request === null)
            return

        var output = root._activeOutput.trim()
        if (output !== "")
            root._applyPayload(request.year, output)

        delete root._requestKeys[request.key]
        root._activeRequest = null
        root._activeOutput = ""
        root._startNext()
    }

    function getDayStatus(year, monthZeroBased, day) {
        var safeYear = root._normaliseYear(year)
        var safeMonth = Number(monthZeroBased)
        var safeDay = Number(day)
        var localDate = new Date(safeYear, safeMonth, safeDay)
        var validDate = safeYear !== 0
            && localDate.getFullYear() === safeYear
            && localDate.getMonth() === safeMonth
            && localDate.getDate() === safeDay

        if (!validDate) {
            return {
                dateKey: "",
                isOffDay: false,
                isWork: true,
                label: "",
                name: "",
                kind: "workday"
            }
        }

        var key = root._dateKey(safeYear, safeMonth, safeDay)
        var yearMap = root._daysByYear[String(safeYear)]
        var known = yearMap ? yearMap[key] : null
        if (known) {
            var off = known.isOffDay === true
            return {
                dateKey: key,
                isOffDay: off,
                isWork: !off,
                label: off ? "休" : "班",
                name: known.name,
                kind: off ? "holiday" : "makeup"
            }
        }

        var dayOfWeek = localDate.getDay()
        var weekend = dayOfWeek === 0 || dayOfWeek === 6
        return {
            dateKey: key,
            isOffDay: weekend,
            isWork: !weekend,
            label: "",
            name: "",
            kind: weekend ? "weekend" : "workday"
        }
    }

    property Process _process: Process {
        command: []
        stdout: StdioCollector {
            id: holidayOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: holidayError
            waitForEnd: true
            onStreamFinished: {
                var message = holidayError.text.trim()
                if (message !== "")
                    console.warn("HolidayService:", message)
            }
        }
        onExited: root._processFinishTimer.restart()
    }

    property Timer _processFinishTimer: Timer {
        interval: 25
        repeat: false
        onTriggered: {
            root._activeOutput = holidayOutput.text
            root._finishRequest()
        }
    }

    property Timer _refreshTimer: Timer {
        interval: 2500
        repeat: false
        onTriggered: root._enqueue("refresh", root._startupYear)
    }

    Component.onCompleted: {
        root.ensureYear(root._startupYear)
        root._refreshTimer.start()
    }
}
