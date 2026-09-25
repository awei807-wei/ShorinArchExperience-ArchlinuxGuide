import QtQuick
import QtQuick.Effects
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../"
import ".."
import "../../components"
import "../../../../components/ImageSourceSafety.js" as SourceSafety

Item {
    id: root

    // ── Source blocklist ──────────────────────────────────────────────────────
    readonly property var _blocked: [
        "kdeconnect", 
        "gsconnect", 
        "playerctld",
        "plasma-browser-integration"
    ]

    // Explicit count tracker — forces filteredPlayers to re-evaluate whenever
    // a player joins or leaves the MPRIS list.
    property int _mprisCount: Mpris.players.values.length

    readonly property var filteredPlayers: {
        var _dep = root._mprisCount  // explicit dependency on list size changes
        var result = []
        var vals = Mpris.players.values
        for (var i = 0; i < vals.length; i++) {
            var id = (vals[i].identity || "").toLowerCase()
            var isBlocked = false
            
            for (var j = 0; j < root._blocked.length; j++) {
                if (id.indexOf(root._blocked[j]) !== -1) {
                    isBlocked = true
                    break
                }
            }
            
            if (!isBlocked) {
                result.push(vals[i])
            }
        }
        return result
    }

    property int selectedPlayerIndex: 0
    property bool _dropdownOpen: false

    // ── Auto-follow the actively playing player ──────────────────────────────
    // Index of the first player whose playbackState is "Playing"
    // (-1 when nothing is playing). Pure reactive binding — the Mpris
    // singleton re-evaluates it on playback state changes.
    readonly property int playingIndex: {
        for (var i = 0; i < root.filteredPlayers.length; i++) {
            if (root.filteredPlayers[i].playbackState === MprisPlaybackState.Playing)
                return i
        }
        return -1
    }

    // The index actually displayed. Auto-follows playingIndex unless the user
    // has pinned a player manually. The pin only suppresses follow-up when a
    // DIFFERENT player starts playing after the manual pick (see below).
    property int activeIndex: {
        if (root.playingIndex !== -1) {
            var p = root._lastManualIndex
            if (p !== -1 && p < root.filteredPlayers.length
                    && p !== root.playingIndex
                    && root._manualPickSeq > root._playingSeq)
                return p   // user just pinned another player manually
            return root.playingIndex
        }
        var m = root._lastManualIndex
        return (m !== -1 && m < root.filteredPlayers.length) ? m : root.selectedPlayerIndex
    }

    // Track a manual pin and version-count playback-start events so a stale
    // pin never overrides a NEW playback (state cycling without count change).
    property int _lastManualIndex: -1
    property int _manualPickSeq: 0
    property int _playingSeq: 0
    onPlayingIndexChanged: {
        if (root.playingIndex !== -1) {
            root._playingSeq++
            root._manualPickSeq = 0   // a fresh start of playback always wins
        }
    }

    onActiveIndexChanged: root.selectedPlayerIndex = root.activeIndex

    onVisibleChanged: if (!visible) root._dropdownOpen = false

    onFilteredPlayersChanged: {
        // Prefer keeping the same player object selected after list change.
        var oldPlayer = root.player
        if (oldPlayer) {
            for (var i = 0; i < root.filteredPlayers.length; i++) {
                if (root.filteredPlayers[i] === oldPlayer) {
                    root.selectedPlayerIndex = i
                    return
                }
            }
        }
        // Fallback: clamp to valid range
        if (root.selectedPlayerIndex >= root.filteredPlayers.length)
            root.selectedPlayerIndex = Math.max(0, root.filteredPlayers.length - 1)
    }

    // ── MPRIS ─────────────────────────────────────────────────────────────────
    // Driven by activeIndex (auto-follows the playing player) instead of the
    // raw manual selection, so "now playing" is displayed without manual pick.
    readonly property var player: root.filteredPlayers.length > 0
                                  ? root.filteredPlayers[root.activeIndex] : null

    readonly property bool   isPlaying: root.player?.playbackState === MprisPlaybackState.Playing ?? false

    readonly property string title: {
        var t = root.player?.trackTitle
        return (t && t !== "") ? t : "Nothing Playing"
    }
    readonly property string artist: {
        var a = root.player?.trackArtists
        if (!a) return ""
        if (typeof a === "string") return a
        if (typeof a.join === "function") return a.join(", ")
        return a.toString()
    }

    // ── VCPChat 增强（VcpSongInfo 单例）：封面 + 真实时长 + 真实进度 ────────────
    // Chromium 的 MPRIS 元数据不含封面；幻影播放源（60s 静音 WAV）让 MPRIS 的
    // length/position 全部失真。单例在"标题/艺术家命中曲库"时回查本地曲库，
    // 并向 rust 音频引擎（127.0.0.1:63789）轮询真实 position/duration。
    // 其他播放器不受影响（_vcpEnhanced 为 false 时全部回退 MPRIS 原始值）。
    readonly property bool  _vcpEnhanced: root.title !== "Nothing Playing"
                                          && VcpSongInfo.matched
    readonly property string artUrl: {
        if (root._vcpEnhanced && VcpSongInfo.artPath !== "") {
            const localArt = SourceSafety.safeFileUrl(VcpSongInfo.artPath)
            if (localArt !== "")
                return localArt
        }
        return SourceSafety.safeSource(root.player?.trackArtUrl ?? "")
    }
    readonly property real _vcpLength: VcpSongInfo.length
    readonly property real length: root._vcpEnhanced && root._vcpLength > 0
                                   ? root._vcpLength
                                   : (root.player?.length ?? 0)
    // 真实进度：引擎活着时用引擎的 current_time（MPRIS 位置是幻影源的）。
    // 注意：不能写成 `readonly property real position:` —— 上一行 128 已有同名
    // 属性（QML 同作用域重复声明 → "Duplicate property name"，且会连带整个
    // 类型加载失败）。position 是仅此一处声明的普通绑定。
    readonly property real vcpPosition: root._vcpEnhanced && VcpSongInfo.engineAlive
                                        && VcpSongInfo.enginePolling
                                        ? VcpSongInfo.enginePos
                                        : (root.player?.position ?? 0)
    readonly property real position: root.vcpPosition

    // 本地缓存的位置（每秒自增 + onPositionChanged 同步；进度条/时间戳/seek 消费）
    property real _pos: 0
    onPositionChanged: root._pos = position
    // 引擎轮询门控：仅 VCPChat 命中且正在播放时开启（1Hz，~1.3KB/次）
    Binding {
        target: VcpSongInfo
        property: "enginePolling"
        value: root._vcpEnhanced && root.isPlaying
    }
    onTitleChanged: VcpSongInfo.lookup(root.title, root.artist)
    // 启动即播放的场景（Mpris 已就绪、title 初始求值）不会触发 onTitleChanged，
    // 必须在完成时主动喂一次，否则曲库匹配永远不发生
    Component.onCompleted: VcpSongInfo.lookup(root.title, root.artist)

    Timer {
        interval: 1000; running: root.isPlaying; repeat: true
        onTriggered: {
            if (root.length > 0)
                root._pos = Math.min(root._pos + 1, root.length)
        }
    }

    function _fmt(sec) {
        var s = Math.floor(sec)
        return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60)
    }

    readonly property real _progress: root.length > 0 ? root._pos / root.length : 0

    // ── Player icon helper ────────────────────────────────────────────────────
    function _playerIcon(player) {
        if (!player) return "♪"
        var id = (player.identity || "").toLowerCase()
        if (id.indexOf("spotify")  !== -1) return ""
        if (id.indexOf("firefox")  !== -1) return ""
        if (id.indexOf("chromium") !== -1) return ""
        if (id.indexOf("chrome")   !== -1) return ""
        if (id.indexOf("brave")    !== -1) return ""
        if (id.indexOf("youtube")  !== -1) return ""
        return "♪"
    }

    // ── Player label helper ───────────────────────────────────────────────────
    function _playerLabel(player) {
        if (!player) return "—"
        var id = (player.identity || "").toLowerCase()
        if (id.indexOf("spotify")  !== -1) return "Spotify"
        if (id.indexOf("firefox")  !== -1) return "Firefox"
        if (id.indexOf("chromium") !== -1) return "Chromium"
        if (id.indexOf("chrome")   !== -1) return "Chrome"
        if (id.indexOf("brave")    !== -1) return "Brave"
        if (id.indexOf("youtube")  !== -1) return "YouTube"
        if (id.indexOf("edge")     !== -1) return "Edge"
        if (id.indexOf("opera")    !== -1) return "Opera"
        if (id.indexOf("vivaldi")  !== -1) return "Vivaldi"
        return player.identity || "Player"
    }

    // ── Background visuals ────────────────────────────────────────────────────
    Item {
        id: bgSource
        anchors.fill:  parent
        opacity:       0
        layer.enabled: true

        Item {
            id: artSource
            anchors.fill:  parent
            layer.enabled: true
            Image {
                anchors.fill: parent
                source:   root.artUrl
                fillMode: Image.PreserveAspectCrop
                smooth:   true
            }
        }

        MultiEffect {
            source:       artSource
            anchors.fill: parent
            visible:      root.artUrl !== ""
            opacity:      root.artUrl !== "" ? 1 : 0
            blurEnabled:  true
            blur:         0.5
            blurMax:      32
            saturation:   0.2
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0,0,0,0.38) }
                GradientStop { position: 0.4; color: Qt.rgba(0,0,0,0.50) }
                GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0.88) }
            }
        }
    }

    Rectangle {
        id: bgMask
        anchors.fill:  parent
        radius:        Theme.cornerRadius
        visible:       false
        layer.enabled: true
    }

    MultiEffect {
        source:           bgSource
        anchors.fill:     parent
        maskEnabled:      true
        maskSource:       bgMask
        maskThresholdMin: 0.5
        maskSpreadAtMin:  1.0
    }

    // ── Track name + artist ───────────────────────────────────────────────────
    Column {
        anchors {
            left:  parent.left;  leftMargin:  120 
            right: parent.right; rightMargin: 120 
            top:   parent.top;   topMargin:   16
        }
        spacing: 4
        clip: true // Ensure nothing bleeds outside the column boundaries
        // ── Title with Marquee Scroll ──
        Item {
            width: parent.width
            height: 22 
            clip: true 
            TextMetrics {
                id: titleMetrics
                font: titleText.font
                text: root.title
            }
            Text {
                id: titleText
                text: root.title
                font.pixelSize: 18; font.weight: Font.Bold
                color: "#ffffff"
                anchors.horizontalCenter: titleMetrics.width <= parent.width ? parent.horizontalCenter : undefined
                NumberAnimation on x {
                    id: marqueeAnim
                    // 面板常驻映射后，跑马灯只能在面板打开时运行，否则会在
                    // 关闭态持续以 60fps 重绘整个内容窗口
                    running: titleMetrics.width > titleText.parent.width && root.isPlaying
                        && Popups.dashboardOpen
                    from: titleText.parent.width
                    to: -titleMetrics.width
                    duration: Math.max(0, (titleMetrics.width + titleText.parent.width) * 20)
                    loops: Animation.Infinite
                }
                onTextChanged: marqueeAnim.restart()
            }
        }
        Text {
            width:   parent.width
            text:    root.artist
            visible: root.artist !== ""
            font.pixelSize: 13
            color: Qt.rgba(1,1,1,0.55) 
            
            maximumLineCount: 1
            elide: Text.ElideRight
            
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // ── Bottom stack: controls + progress (raised to give room for picker) ──────
    Column {
        anchors {
            left:   parent.left;   leftMargin:   14
            right:  parent.right;  rightMargin:  14
            bottom: parent.bottom; bottomMargin: 54
        }
        spacing: 6

        // Controls
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 28
            Repeater {
                model: [ { key: "prev" }, { key: "play" }, { key: "next" } ]
                delegate: Rectangle {
                    required property var  modelData
                    required property int  index
                    readonly property bool isPlay: modelData.key === "play"
                    readonly property string dispIcon: {
                        if (modelData.key === "prev") return "󰒫"
                        if (modelData.key === "next") return "󰒬"
                        return !root.isPlaying ? "󰐊" : "󰏤"
                    }
                    width: 36; height: 36 
                    radius: height / 2
                    color: isPlay
                           ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                           : cH.hovered ? Qt.rgba(1,1,1,0.14) : Qt.rgba(1,1,1,0.06)
                    border.color: isPlay ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.3) : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent
                        text: parent.dispIcon
                        font.pixelSize: isPlay ? 18 : 14
                        color: isPlay ? Theme.active : Qt.rgba(1,1,1,0.7)
                    }
                    HoverHandler { id: cH; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (!root.player) return
                            switch (modelData.key) {
                                case "play":
                                    if (root.player.canTogglePlaying)
                                        root.player.isPlaying = !root.player.isPlaying
                                    break
                                case "prev":
                                    if (root.player.canGoPrevious) root.player.previous()
                                    break
                                case "next":
                                    if (root.player.canGoNext) root.player.next()
                                    break
                            }
                        }
                    }
                }
            }
        }

        // Progress bar + timestamps
        Column {
            width: parent.width; spacing: 3
            Item {
                width: parent.width; height: 6
                Rectangle {
                    anchors.fill: parent; radius: height / 2
                    color: Qt.rgba(1,1,1,0.2)
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            if (root.player && root.length > 0) {
                                var f = mouse.x / width
                                root.player.position = f * root.length
                                root._pos = f * root.length
                            }
                        }
                    }
                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width:  Math.max(radius * 2, parent.width * root._progress)
                        radius: parent.radius; color: Theme.active
                        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }
                }
            }
            Item {
                width: parent.width; height: 14

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: root._fmt(root._pos)
                    font.pixelSize: 9; font.family: "JetBrains Mono"
                    color: Qt.rgba(1,1,1,0.4)
                }

                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: root._fmt(root.length)
                    font.pixelSize: 9; font.family: "JetBrains Mono"
                    color: Qt.rgba(1,1,1,0.4)
                }
            }
        }
    }

    // ── Source picker — upward-expanding pill ─────────────────────────────────
    // Sits in the gap between the controls and the card bottom; expands upward.
    Item {
        id: sourcePicker
        anchors {
            top:          parent.top
            right:        parent.right
            topMargin:    12
            rightMargin:  12
        }
        visible: root.filteredPlayers.length > 1
        z:       30
        
        width:  pill.width
        height: pill.height

        Rectangle {
            id: pill
            anchors.top:   parent.top
            anchors.right: parent.right

            // Width tracks the active row + padding
            width: activeRow.implicitWidth + 24

            readonly property int _rowH: 26
            height: root._dropdownOpen 
                    ? (_rowH * root.filteredPlayers.length) 
                    : _rowH
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            radius:       _rowH / 2
            clip:         true
            color:        Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.15)
            border.color: root._dropdownOpen
                          ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.30)
                          : "transparent"
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 150 } }

            // Stacks downward from the top
            Column {
                anchors.top:   parent.top
                anchors.left:  parent.left
                anchors.right: parent.right
                spacing: 0

                // ── Active player row (Always at the top) ─────────────
                Item {
                    height: pill._rowH
                    width:  parent.width

                    Row {
                        id: activeRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text:           root.player ? root._playerIcon(root.player) : "♪"
                            font.pixelSize: 11
                            color:          Theme.active
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text:           root.player ? root._playerLabel(root.player) : "Player"
                            font.pixelSize: 11
                            font.weight:    Font.Medium
                            color:          Qt.rgba(1,1,1,0.92)
                            // Cap width so crazy browser identities don't stretch the pill
                            width:          Math.min(implicitWidth, 120) 
                            elide:          Text.ElideRight
                        }
                    }

                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked:    root._dropdownOpen = !root._dropdownOpen
                    }
                }

                // ── Other player rows (Drop down below active) ─────────
                Repeater {
                    model: root.filteredPlayers
                    delegate: Item {
                        required property var modelData
                        required property int index
                        readonly property bool isCurrent: index === root.selectedPlayerIndex

                        width:  parent.width
                        height: isCurrent ? 0 : (root._dropdownOpen ? pill._rowH : 0)
                        visible: !isCurrent
                        opacity: root._dropdownOpen ? 1 : 0
                        
                        Behavior on height  { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 140 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text:           root._playerIcon(modelData)
                                font.pixelSize: 11
                                color:          rowH.hovered ? Qt.rgba(1,1,1,0.90) : Qt.rgba(1,1,1,0.55)
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text:           root._playerLabel(modelData)
                                font.pixelSize: 11
                                color:          rowH.hovered ? Qt.rgba(1,1,1,0.90) : Qt.rgba(1,1,1,0.55)
                                width:          Math.min(implicitWidth, 120)
                                elide:          Text.ElideRight
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                        }

                        HoverHandler { id: rowH; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                // Manual pick: pin this player until a NEW
                                // playback starts elsewhere (see activeIndex).
                                root._lastManualIndex = index
                                root._manualPickSeq = root._playingSeq + 1
                                root.selectedPlayerIndex = index
                                root._dropdownOpen = false
                            }
                        }
                    }
                }
            }
        }
    } 

    // ── VCPChat-style spectrum — gradient curve + vocal waves + particles ─────
    SpectrumVisualizer {
        id: spectrumVisualizer
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 7; rightMargin: 7; bottomMargin: 4 }
        height: 48
        spectrum: CavaService.easedSpectrum
        // 只在采集链路激活时重绘：卡片常驻可见后，不能再以 visible 作为
        // 60fps 重绘的开关
        running: CavaService.active && root.visible
        tint: Theme.active
    }

    // Border
    Rectangle {
        anchors.fill: parent
        radius:       Theme.cornerRadius
        color:        "transparent"
        border.color: Qt.rgba(1,1,1,0.08)
        border.width: 1
    }

    // Close dropdown on click outside
    TapHandler {
        enabled: root._dropdownOpen
        onTapped: root._dropdownOpen = false
    }
}
