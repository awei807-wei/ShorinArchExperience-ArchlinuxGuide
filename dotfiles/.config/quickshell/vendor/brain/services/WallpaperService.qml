pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Shared wallpaper state watcher. The hook atomically replaces the JSON file,
// and this singleton fans the update out to every dashboard instance.
QtObject {
    id: root

    signal wallpaperApplied(string path)

    readonly property string _homeDir: {
        var home = Quickshell.env("HOME")
        if (home === null || home === undefined || home === "")
            return "/home/shiyi"
        return String(home)
    }
    readonly property string _statePath: root._homeDir + "/.cache/quickshell/wallpaper-state.json"

    property string avatarPath: root._homeDir + "/.curr_wall_static.jpg"
    property string sourcePath: ""
    property int revision: 0

    function _parseState() {
        try {
            var raw = root._stateView.text()
            if (raw === null || raw === undefined || String(raw).trim() === "")
                throw new Error("empty wallpaper state")

            var parsed = JSON.parse(String(raw))
            if (!parsed || typeof parsed !== "object")
                throw new Error("wallpaper state is not an object")

            var source = parsed.source === null || parsed.source === undefined
                ? "" : String(parsed.source)
            var avatar = parsed.avatar === null || parsed.avatar === undefined
                ? "" : String(parsed.avatar)
            var updatedAt = parsed.updatedAt === null || parsed.updatedAt === undefined
                ? "" : String(parsed.updatedAt)
            if (source === "" || avatar === "" || updatedAt === "")
                throw new Error("wallpaper state is missing required fields")

            root.sourcePath = source
            root.avatarPath = avatar
            root.revision += 1
            root.wallpaperApplied(source)
        } catch (error) {
            // Atomic writes make parse failures unlikely; if one occurs, keep the
            // last known-good paths and wait for the next file change.
            console.warn("WallpaperService: invalid wallpaper state:", error)
        }
    }

    property Timer _reloadTimer: Timer {
        interval: 50
        repeat: false
        onTriggered: root._stateView.reload()
    }

    property Timer _missingStateRetry: Timer {
        interval: 2000
        repeat: false
        onTriggered: root._stateView.reload()
    }

    property FileView _stateView: FileView {
        path: root._statePath
        watchChanges: true
        onFileChanged: root._reloadTimer.restart()
        onLoaded: {
            root._missingStateRetry.stop()
            root._parseState()
        }
        onLoadFailed: root._missingStateRetry.restart()
    }

    // FileView does not load merely because path is assigned.
    Component.onCompleted: root._stateView.reload()
}
