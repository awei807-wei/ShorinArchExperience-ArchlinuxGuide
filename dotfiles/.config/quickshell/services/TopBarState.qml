pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

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
    property real previousCpuIdle: 0
    property real previousCpuTotal: 0
    property real memTotal: 0
    property real memAvailable: 0
    readonly property var battery: UPower.displayDevice
    readonly property bool batteryAvailable: battery !== null
        && battery.ready && battery.isPresent
    readonly property int batteryPercent: batteryAvailable
        ? clampPercent(battery.percentage * 100) : 100

    property string weatherText: "--°C"
    property string lastValidWeather: ""
    property bool weatherReceivedOutput: false
    property int weatherRetryCount: 0
    readonly property int weatherMaxRetries: 3
    readonly property string weatherScriptPath: env("HOME")
        + "/.config/waybar/scripts/weather.py"

    function env(name) {
        const value = Quickshell.env(name)
        return value === null || value === undefined ? "" : String(value)
    }

    function clampPercent(value) {
        return Math.max(0, Math.min(100, Math.round(value)))
    }

    function refreshMetrics() {
        if (!cpuProcess.running)
            cpuProcess.running = true
        if (!memoryProcess.running)
            memoryProcess.running = true
    }

    function startWeatherFetch(resetRetries) {
        if (resetRetries)
            weatherRetryCount = 0
        if (weatherProcess.running)
            return
        weatherReceivedOutput = false
        weatherProcess.running = true
    }

    Component.onCompleted: {
        if (!testMode) {
            refreshMetrics()
            weatherStartTimer.start()
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

}
