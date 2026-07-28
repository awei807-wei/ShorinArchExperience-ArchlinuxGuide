pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: topBarState

    readonly property bool testMode: {
        const value = env("QUICKSHELL_TEST_MODE").toLowerCase()
        return value === "1" || value === "true" || value === "yes"
    }
    readonly property string desktopProbe: (env("XDG_CURRENT_DESKTOP") + " "
        + env("XDG_SESSION_DESKTOP") + " "
        + env("DESKTOP_SESSION")).toLowerCase()
    readonly property string sessionType: {
        const value = env("XDG_SESSION_TYPE")
        return value === "" ? "SESSION" : value.toUpperCase()
    }
    readonly property string desktopName: {
        if (desktopProbe.indexOf("plasma") !== -1 || desktopProbe.indexOf("kde") !== -1)
            return "PLASMA"
        if (desktopProbe.indexOf("gnome") !== -1)
            return "GNOME"
        if (desktopProbe.indexOf("hypr") !== -1)
            return "HYPRLAND"
        if (desktopProbe.indexOf("niri") !== -1)
            return "NIRI"

        const currentDesktop = env("XDG_CURRENT_DESKTOP")
        return currentDesktop === "" ? "DESKTOP" : currentDesktop.split(":")[0].toUpperCase()
    }
    readonly property string contextMode: {
        if (env("NIRI_SOCKET") !== "" || desktopProbe.indexOf("niri") !== -1)
            return "niri"
        if (env("HYPRLAND_INSTANCE_SIGNATURE") !== "" || desktopProbe.indexOf("hypr") !== -1)
            return "hyprland"
        if (desktopProbe.indexOf("plasma") !== -1 || desktopProbe.indexOf("kde") !== -1
                || desktopProbe.indexOf("gnome") !== -1)
            return "desktop"
        return "fallback"
    }
    readonly property bool reducedMotion: {
        const value = env("QUICKSHELL_REDUCE_MOTION").toLowerCase()
        return value === "1" || value === "true" || value === "yes"
    }

    property int cpuPercent: 0
    property int memPercent: 0
    property real networkBytesPerSecond: 0
    property string networkRateText: "--"
    property int networkLevel: 0
    property real previousCpuIdle: 0
    property real previousCpuTotal: 0
    property real memTotal: 0
    property real memAvailable: 0
    property real previousNetworkBytes: -1
    property real previousNetworkTimestamp: 0
    property real networkSampleBytes: 0

    property string weatherText: "--°C"
    property string lastValidWeather: ""
    property bool weatherReceivedOutput: false
    property int weatherRetryCount: 0
    readonly property int weatherMaxRetries: 3
    readonly property string weatherScriptPath: env("HOME")
        + "/.config/waybar/scripts/weather.py"

    property string cavaData: "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁"
    property bool cavaActive: false
    property string pendingCavaData: ""
    property bool pendingCavaActive: false
    property bool cavaParseErrorLogged: false

    function env(name) {
        const value = Quickshell.env(name)
        return value === null || value === undefined ? "" : String(value)
    }

    function clampPercent(value) {
        return Math.max(0, Math.min(100, Math.round(value)))
    }

    function formatRate(bytesPerSecond) {
        if (bytesPerSecond >= 1024 * 1024) {
            const value = bytesPerSecond / (1024 * 1024)
            return value.toFixed(value >= 10 ? 0 : 1) + "M"
        }
        if (bytesPerSecond >= 1024) {
            const value = bytesPerSecond / 1024
            return value.toFixed(value >= 10 ? 0 : 1) + "K"
        }
        return Math.round(bytesPerSecond) + "B"
    }

    function rateLevel(bytesPerSecond) {
        const thresholds = [1, 1024, 8192, 32768, 131072, 524288, 2097152, 8388608]
        let level = 0
        for (let index = 0; index < thresholds.length; index += 1) {
            if (bytesPerSecond >= thresholds[index])
                level = index + 1
        }
        return level
    }

    function refreshMetrics() {
        if (!cpuProcess.running)
            cpuProcess.running = true
        if (!memoryProcess.running)
            memoryProcess.running = true
        if (!networkProcess.running) {
            networkSampleBytes = 0
            networkProcess.running = true
        }
    }

    function startWeatherFetch(resetRetries) {
        if (resetRetries)
            weatherRetryCount = 0
        if (weatherProcess.running)
            return
        weatherReceivedOutput = false
        weatherProcess.running = true
    }

    function startCava() {
        if (!cavaProcess.running)
            cavaProcess.running = true
    }

    Component.onCompleted: {
        if (!testMode) {
            refreshMetrics()
            weatherStartTimer.start()
            startCava()
        }
    }

    Timer {
        interval: 2000
        running: !topBarState.testMode
        repeat: true
        onTriggered: topBarState.refreshMetrics()
    }

    Process {
        id: cpuProcess
        command: ["cat", "/proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                if (!data.startsWith("cpu "))
                    return

                const parts = data.trim().split(/\s+/)
                const user = Number(parts[1]) || 0
                const nice = Number(parts[2]) || 0
                const system = Number(parts[3]) || 0
                const idle = Number(parts[4]) || 0
                const ioWait = Number(parts[5]) || 0
                const irq = Number(parts[6]) || 0
                const softIrq = Number(parts[7]) || 0
                const steal = Number(parts[8]) || 0
                const total = user + nice + system + idle + ioWait + irq + softIrq + steal
                const idleTotal = idle + ioWait
                const totalDelta = total - topBarState.previousCpuTotal
                const idleDelta = idleTotal - topBarState.previousCpuIdle

                topBarState.previousCpuTotal = total
                topBarState.previousCpuIdle = idleTotal
                if (totalDelta > 0)
                    topBarState.cpuPercent = topBarState.clampPercent((1 - idleDelta / totalDelta) * 100)
            }
        }
    }

    Process {
        id: memoryProcess
        command: ["cat", "/proc/meminfo"]
        stdout: SplitParser {
            onRead: data => {
                if (data.startsWith("MemTotal:")) {
                    topBarState.memTotal = Number(data.trim().split(/\s+/)[1]) || 0
                    return
                }
                if (!data.startsWith("MemAvailable:"))
                    return

                topBarState.memAvailable = Number(data.trim().split(/\s+/)[1]) || 0
                if (topBarState.memTotal > 0) {
                    topBarState.memPercent = topBarState.clampPercent(
                        (topBarState.memTotal - topBarState.memAvailable) * 100 / topBarState.memTotal)
                }
            }
        }
    }

    Process {
        id: networkProcess
        command: ["cat", "/proc/net/dev"]
        onExited: {
            const now = Date.now()
            if (topBarState.previousNetworkBytes >= 0 && topBarState.previousNetworkTimestamp > 0) {
                const elapsedSeconds = Math.max(0.001,
                    (now - topBarState.previousNetworkTimestamp) / 1000)
                const byteDelta = Math.max(0,
                    topBarState.networkSampleBytes - topBarState.previousNetworkBytes)
                topBarState.networkBytesPerSecond = byteDelta / elapsedSeconds
                topBarState.networkRateText = topBarState.formatRate(topBarState.networkBytesPerSecond)
                topBarState.networkLevel = topBarState.rateLevel(topBarState.networkBytesPerSecond)
            }
            topBarState.previousNetworkBytes = topBarState.networkSampleBytes
            topBarState.previousNetworkTimestamp = now
        }
        stdout: SplitParser {
            onRead: data => {
                const match = data.match(/^\s*([^:]+):\s*(.*)$/)
                if (!match || match[1].trim() === "lo")
                    return

                const fields = match[2].trim().split(/\s+/)
                const received = Number(fields[0]) || 0
                const transmitted = Number(fields[8]) || 0
                topBarState.networkSampleBytes += received + transmitted
            }
        }
    }

    Process {
        id: weatherProcess
        command: ["/usr/bin/python", "-u", topBarState.weatherScriptPath]
        onStarted: topBarState.weatherReceivedOutput = false
        onExited: {
            if (topBarState.weatherReceivedOutput)
                return

            topBarState.weatherRetryCount += 1
            if (topBarState.weatherRetryCount < topBarState.weatherMaxRetries) {
                weatherRetryTimer.restart()
            } else {
                topBarState.weatherText = topBarState.lastValidWeather !== ""
                    ? topBarState.lastValidWeather : "--°C"
                topBarState.weatherRetryCount = 0
            }
        }
        stdout: SplitParser {
            onRead: data => {
                const trimmed = data.trim()
                if (!trimmed.startsWith("{") || !trimmed.endsWith("}"))
                    return

                try {
                    const payload = JSON.parse(trimmed)
                    if (!payload.text)
                        return

                    topBarState.weatherReceivedOutput = true
                    if (payload.text.indexOf("--") !== -1) {
                        topBarState.weatherRetryCount += 1
                        if (topBarState.weatherRetryCount < topBarState.weatherMaxRetries)
                            weatherRetryTimer.restart()
                        else
                            topBarState.weatherRetryCount = 0
                        return
                    }

                    topBarState.weatherText = payload.text
                    topBarState.lastValidWeather = payload.text
                    topBarState.weatherRetryCount = 0
                } catch (error) {
                    console.warn("[TopBarState] invalid weather payload: " + error)
                }
            }
        }
    }

    Timer {
        id: weatherStartTimer
        interval: 1500
        repeat: false
        onTriggered: topBarState.startWeatherFetch(true)
    }

    Timer {
        id: weatherRetryTimer
        interval: 5000
        repeat: false
        onTriggered: topBarState.startWeatherFetch(false)
    }

    Timer {
        interval: 900000
        running: !topBarState.testMode
        repeat: true
        onTriggered: topBarState.startWeatherFetch(true)
    }

    Process {
        id: cavaProcess
        command: [Quickshell.shellDir + "/scripts/cava.sh"]
        onExited: {
            if (!topBarState.testMode)
                cavaRetryTimer.restart()
        }
        stdout: SplitParser {
            onRead: data => {
                try {
                    const payload = JSON.parse(data)
                    if (typeof payload.bars === "string" && payload.bars !== "")
                        topBarState.pendingCavaData = payload.bars
                    topBarState.pendingCavaActive = payload.active === true
                } catch (error) {
                    if (!topBarState.cavaParseErrorLogged) {
                        topBarState.cavaParseErrorLogged = true
                        console.warn("[TopBarState] invalid cava payload: " + error)
                    }
                }
            }
        }
    }

    Timer {
        id: cavaFrameTimer
        interval: 180
        running: !topBarState.testMode && !topBarState.reducedMotion
        repeat: true
        onTriggered: {
            if (topBarState.pendingCavaData !== "")
                topBarState.cavaData = topBarState.pendingCavaData
            topBarState.cavaActive = topBarState.pendingCavaActive
        }
    }

    Timer {
        id: cavaRetryTimer
        interval: 10000
        repeat: false
        onTriggered: topBarState.startCava()
    }
}
