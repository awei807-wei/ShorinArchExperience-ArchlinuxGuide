// 通知历史的轻量进程桥：常驻内存仅保留计数和串行任务队列。
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: historyStore

    property int historyCount: 0
    property int maxPendingAppends: 200
    property string historyPathOverride: ""
    property string errorMessage: ""
    property string warningMessage: ""
    readonly property bool busy: historyProcess.running || operationQueue.length > 0
    readonly property bool copyBusy: copyProcess.running || copyQueue.length > 0

    property var operationQueue: []
    property var activeOperation: null
    property var copyQueue: []
    property var activeCopy: null

    signal historyLoaded(var entries, bool recovered, string warning)
    signal historyLoadFailed(string message)
    signal historyAppended()
    signal historyCleared()
    signal operationFailed(string operation, string message)
    signal copySucceeded()
    signal copyFailed(string message)

    function appendSnapshot(snapshot) {
        enqueue("append", JSON.stringify(snapshot) + "\n")
    }

    function loadHistory() {
        const listPending = activeOperation?.operation === "list"
            || operationQueue.some(item => item.operation === "list")
        if (listPending)
            return
        enqueue("list", "")
    }

    function refreshCount() {
        enqueue("count", "")
    }

    function clearHistory() {
        enqueue("clear", "")
    }

    function enqueue(operation, input) {
        let pending = operationQueue.concat([{
            "operation": operation,
            "input": input
        }])
        if (operation === "append") {
            let appendCount = pending.filter(item => item.operation === "append").length
            while (appendCount > maxPendingAppends) {
                const oldestAppend = pending.findIndex(item => item.operation === "append")
                pending.splice(oldestAppend, 1)
                appendCount -= 1
            }
        }
        operationQueue = pending
        runNext()
    }

    function runNext() {
        if (historyProcess.running || activeOperation !== null || operationQueue.length === 0)
            return

        const pending = operationQueue.slice()
        activeOperation = pending.shift()
        operationQueue = pending
        const command = [
            "python3",
            Quickshell.shellPath("scripts/notification-history.py"),
            activeOperation.operation
        ]
        historyProcess.command = historyPathOverride === ""
            ? command
            : ["env", "QUICKSHELL_NOTIFICATION_HISTORY_PATH=" + historyPathOverride].concat(command)
        historyProcess.running = true
    }

    function lastJsonLine(rawText) {
        const lines = String(rawText || "").trim().split("\n")
        for (let index = lines.length - 1; index >= 0; index--) {
            if (lines[index].trim().length > 0)
                return lines[index]
        }
        return ""
    }

    function finishOperation(exitCode) {
        const operation = activeOperation ? activeOperation.operation : "unknown"
        let response = null
        let parseMessage = ""
        try {
            const jsonLine = lastJsonLine(historyStdout.text)
            if (jsonLine.length > 0)
                response = JSON.parse(jsonLine)
            else
                parseMessage = "存储器未返回结果"
        } catch (error) {
            parseMessage = "无法解析存储器结果: " + error
        }

        if (exitCode !== 0 || !response || response.ok !== true) {
            const stderrText = String(historyStderr.text || "").trim()
            const message = response?.error || parseMessage || stderrText || ("存储器退出码 " + exitCode)
            errorMessage = message
            if (operation === "list")
                historyLoadFailed(message)
            operationFailed(operation, message)
        } else {
            errorMessage = ""
            warningMessage = response.warning || ""
            historyCount = Number(response.count) || 0
            if (operation === "list") {
                const entries = Array.isArray(response.notifications) ? response.notifications : []
                historyLoaded(entries, response.recovered === true, warningMessage)
            } else if (operation === "append") {
                historyAppended()
            } else if (operation === "clear") {
                historyCleared()
            }
        }

        activeOperation = null
        Qt.callLater(runNext)
    }

    function entryText(entry) {
        const numericTimestamp = Number(entry?.timestamp || 0)
        const date = new Date(numericTimestamp)
        const timestamp = isNaN(date.getTime())
            ? String(entry?.timestamp || "")
            : Qt.formatDateTime(date, "yyyy-MM-dd HH:mm:ss")
        return [
            "来源应用（D-Bus appName）: " + (entry?.appName || "Unknown"),
            "Desktop Entry: " + (entry?.desktopEntry || "Unknown"),
            "通知 ID: " + String(entry?.id ?? "Unknown"),
            "紧急度: " + (entry?.urgency || "Normal"),
            "时间: " + timestamp,
            "标题: " + (entry?.summary || ""),
            "正文:",
            entry?.body || ""
        ].join("\n")
    }

    function copyEntry(entry) {
        if (!entry)
            return
        copyQueue = copyQueue.concat([entryText(entry)]).slice(-4)
        runNextCopy()
    }

    function runNextCopy() {
        if (copyProcess.running || activeCopy !== null || copyQueue.length === 0)
            return

        const pending = copyQueue.slice()
        activeCopy = pending.shift()
        copyQueue = pending
        copyProcess.command = ["wl-copy", activeCopy]
        copyProcess.running = true
    }

    Component.onCompleted: refreshCount()

    Process {
        id: historyProcess
        stdinEnabled: true
        stdout: StdioCollector {
            id: historyStdout
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: historyStderr
            waitForEnd: true
        }
        onStarted: {
            if (historyStore.activeOperation?.input)
                historyProcess.write(historyStore.activeOperation.input)
        }
        onExited: (exitCode, exitStatus) => historyStore.finishOperation(exitCode)
    }

    Process {
        id: copyProcess
        stderr: StdioCollector {
            id: copyStderr
            waitForEnd: true
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                historyStore.copySucceeded()
            } else {
                historyStore.copyFailed(String(copyStderr.text || "wl-copy 执行失败").trim())
            }
            historyStore.activeCopy = null
            Qt.callLater(historyStore.runNextCopy)
        }
    }
}
