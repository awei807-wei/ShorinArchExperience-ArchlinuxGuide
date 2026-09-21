pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Shared reactive task store for Agenda, Calendar and Kanban.
// All mutations replace both the changed object and the containing array so
// bindings in every consumer are notified immediately.
QtObject {
    id: root

    property var tasks: []
    property int nextId: 0
    property bool loaded: false

    readonly property string _homeDir: {
        var home = Quickshell.env("HOME")
        if (home === null || home === undefined || home === "")
            return "/home/shiyi"
        return home
    }
    readonly property string _dataDir: root._homeDir + "/.config/quickshell/vendor/brain/user_data"
    readonly property string _filePath: root._dataDir + "/tasks.json"

    property bool _canSave: false
    property bool _saveQueued: false
    property int _loadRetries: 0

    function _normaliseTask(raw, fallbackId) {
        var source = raw && typeof raw === "object" ? raw : ({})
        var id = Number(source.id)
        if (!isFinite(id) || id < 0)
            id = fallbackId
        id = Math.floor(id)

        var column = Number(source.column)
        if (!isFinite(column))
            column = 0
        column = Math.max(0, Math.min(2, Math.floor(column)))

        var urgency = source.urgency === undefined || source.urgency === null
            ? "" : String(source.urgency)
        if (urgency !== "high" && urgency !== "medium" && urgency !== "low")
            urgency = ""

        return {
            id: id,
            title: source.title === undefined || source.title === null ? "" : String(source.title),
            column: column,
            urgency: urgency,
            dueDate: source.dueDate === undefined || source.dueDate === null ? "" : String(source.dueDate),
            pinned: source.pinned === true
        }
    }

    function _finishLoad(text) {
        try {
            var parsed = JSON.parse(text)
            if (!parsed || !Array.isArray(parsed.tasks))
                throw new Error("tasks.json does not contain a tasks array")

            var normalised = []
            var maxId = -1
            for (var i = 0; i < parsed.tasks.length; ++i) {
                var task = root._normaliseTask(parsed.tasks[i], maxId + 1)
                normalised.push(task)
                maxId = Math.max(maxId, task.id)
            }

            var parsedNextId = Number(parsed.nextId)
            if (!isFinite(parsedNextId) || parsedNextId < 0)
                parsedNextId = 0
            parsedNextId = Math.floor(parsedNextId)

            var safeNextId = Math.max(parsedNextId, maxId + 1)
            var needsMigration = JSON.stringify(parsed.tasks) !== JSON.stringify(normalised)
                || parsedNextId !== safeNextId

            root.tasks = normalised
            root.nextId = safeNextId
            root._canSave = true
            root.loaded = true
            root._loadRetries = 0

            if (needsMigration)
                root.saveTasks()
        } catch (error) {
            root._canSave = false
            if (root._loadRetries < 3) {
                root._loadRetries += 1
                loadRetry.restart()
            } else {
                root.loaded = true
                console.warn("TaskService: failed to parse tasks.json:", error)
            }
        }
    }

    function loadTasks() {
        if (loadProcess.running)
            return

        root.loaded = false
        loadProcess.command = [
            "sh", "-c",
            "set -eu\n"
                + "mkdir -p \"$1\"\n"
                + "if [ ! -f \"$2\" ]; then\n"
                + "  tmp=\"$2.tmp.$$\"\n"
                + "  trap 'rm -f \"$tmp\"' EXIT HUP INT TERM\n"
                + "  printf '%s' '{\"tasks\":[],\"nextId\":0}' > \"$tmp\"\n"
                + "  mv -f \"$tmp\" \"$2\"\n"
                + "  trap - EXIT\n"
                + "fi\n"
                + "cat \"$2\"",
            "task-service",
            root._dataDir,
            root._filePath
        ]
        loadProcess.running = true
    }

    function saveTasks() {
        if (!root.loaded || !root._canSave)
            return
        saveTimer.restart()
    }

    function _writeNow() {
        if (!root.loaded || !root._canSave)
            return
        if (writeProcess.running) {
            root._saveQueued = true
            return
        }

        var payload = JSON.stringify({ tasks: root.tasks, nextId: root.nextId })
        writeProcess.command = [
            "sh", "-c",
            "set -eu\n"
                + "mkdir -p \"$1\"\n"
                + "tmp=\"$2.tmp.$$\"\n"
                + "trap 'rm -f \"$tmp\"' EXIT HUP INT TERM\n"
                + "printf '%s' \"$3\" > \"$tmp\"\n"
                + "mv -f \"$tmp\" \"$2\"\n"
                + "trap - EXIT",
            "task-service",
            root._dataDir,
            root._filePath,
            payload
        ]
        writeProcess.running = true
    }

    function addTask(col, title, urgency, dueDate, pinned) {
        if (!root.loaded || !root._canSave)
            return -1

        var cleanTitle = title === undefined || title === null ? "" : String(title).trim()
        if (cleanTitle === "")
            return -1

        var column = Number(col)
        if (!isFinite(column))
            column = 0
        column = Math.max(0, Math.min(2, Math.floor(column)))

        var cleanUrgency = urgency === undefined || urgency === null ? "" : String(urgency)
        if (cleanUrgency !== "high" && cleanUrgency !== "medium" && cleanUrgency !== "low")
            cleanUrgency = ""

        var id = root.nextId
        var task = {
            id: id,
            title: cleanTitle,
            column: column,
            urgency: cleanUrgency,
            dueDate: dueDate === undefined || dueDate === null ? "" : String(dueDate),
            pinned: pinned === true
        }
        var list = root.tasks.slice()
        list.unshift(task)
        root.nextId = id + 1
        root.tasks = list
        root.saveTasks()
        return id
    }

    function patchTask(id, key, val) {
        if (!root.loaded || !root._canSave)
            return false
        if (key !== "title" && key !== "column" && key !== "urgency"
                && key !== "dueDate" && key !== "pinned")
            return false

        var list = root.tasks.slice()
        for (var i = 0; i < list.length; ++i) {
            if (list[i].id !== id)
                continue

            var value = val
            if (key === "title") {
                value = val === undefined || val === null ? "" : String(val).trim()
                if (value === "")
                    return false
            } else if (key === "column") {
                value = Number(val)
                if (!isFinite(value))
                    return false
                value = Math.max(0, Math.min(2, Math.floor(value)))
            } else if (key === "urgency") {
                value = val === undefined || val === null ? "" : String(val)
                if (value !== "high" && value !== "medium" && value !== "low")
                    value = ""
            } else if (key === "dueDate") {
                value = val === undefined || val === null ? "" : String(val)
            } else if (key === "pinned") {
                value = val === true
            }

            if (list[i][key] === value)
                return true

            var changed = Object.assign({}, list[i])
            changed[key] = value
            list[i] = changed
            root.tasks = list
            root.saveTasks()
            return true
        }
        return false
    }

    function moveTask(id, dir) {
        if (!root.loaded || !root._canSave)
            return false
        var direction = Number(dir)
        if (!isFinite(direction) || direction === 0)
            return false
        direction = direction > 0 ? 1 : -1

        for (var i = 0; i < root.tasks.length; ++i) {
            if (root.tasks[i].id !== id)
                continue
            var nextColumn = root.tasks[i].column + direction
            if (nextColumn < 0 || nextColumn > 2)
                return false
            return root.patchTask(id, "column", nextColumn)
        }
        return false
    }

    function markDone(id) {
        return root.patchTask(id, "column", 2)
    }

    function removeTask(id) {
        if (!root.loaded || !root._canSave)
            return false
        var list = root.tasks.filter(function(task) { return task.id !== id })
        if (list.length === root.tasks.length)
            return false
        root.tasks = list
        root.saveTasks()
        return true
    }

    property Timer saveTimer: Timer {
        interval: 120
        repeat: false
        onTriggered: root._writeNow()
    }

    property Timer loadRetry: Timer {
        interval: 400
        repeat: false
        onTriggered: root.loadTasks()
    }

    property Process loadProcess: Process {
        command: []
        stdout: StdioCollector {
            onStreamFinished: root._finishLoad(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                var message = text.trim()
                if (message !== "")
                    console.warn("TaskService load:", message)
            }
        }
    }

    property Process writeProcess: Process {
        command: []
        onExited: {
            if (root._saveQueued) {
                root._saveQueued = false
                root._writeNow()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                var message = text.trim()
                if (message !== "")
                    console.warn("TaskService save:", message)
            }
        }
    }

    Component.onCompleted: root.loadTasks()
}
