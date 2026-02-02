//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
ShellRoot {
    id: root

    // ═══════════════════════════════════════════════════════
    // 🎛️ 主控参数 - 只需要调这一个
    // ═══════════════════════════════════════════════════════
    readonly property real k: 6                    // K越大UI越小，K越小UI越大

    // ═══════════════════════════════════════════════════════
    // 📐 L0 · 基准单位（自动计算）
    // ═══════════════════════════════════════════════════════
    readonly property real ppi: 144                // 屏幕PPI，可根据实际调整
    readonly property real baseUnit: Math.round(ppi / k)

    // ═══════════════════════════════════════════════════════
    // 🏝️ L1 · 岛屿几何
    // ═══════════════════════════════════════════════════════
    readonly property real islandHeight: baseUnit * 2.0       // 岛屿高度
    readonly property real islandRadius: islandHeight * 0.35  // 岛屿圆角
    readonly property real islandPaddingH: baseUnit * 1.4     // 岛屿水平内边距
    readonly property real islandPaddingV: baseUnit * 0.4     // 岛屿垂直内边距
    readonly property real islandGap: baseUnit * 0.8          // 岛屿之间间距
    readonly property real barMarginTop: baseUnit * 0.8       // 顶栏距屏幕顶部
    readonly property real barMarginSide: baseUnit * 0.2        // 顶栏左右边距
    // 岛屿位置偏移（正值向右，负值向左）
    readonly property real leftIslandOffsetX:   baseUnit * 0    // 左岛X偏移
    readonly property real centerIslandOffsetX: baseUnit * 16    // 中岛X偏移
    readonly property real rightIslandOffsetX:  baseUnit * 0    // 右岛X偏移

    // ═══════════════════════════════════════════════════════
    // 🔤 L2 · 字体与图标
    // ═══════════════════════════════════════════════════════
    readonly property real fontPrimary: baseUnit * 0.9        // 主字体（时间等）
    readonly property real fontSecondary: baseUnit * 0.7      // 次要字体（标签等）
    readonly property real fontTiny: baseUnit * 0.5           // 最小字体
    readonly property real fontSection: baseUnit * 0.28       // 分区标题字体
    readonly property real iconSize: baseUnit * 1.2           // 图标尺寸
    readonly property real iconSizeSmall: baseUnit * 0.8      // 小图标尺寸

    // ═══════════════════════════════════════════════════════
    // 📦 L3 · 子面板
    // ═══════════════════════════════════════════════════════
    readonly property real panelWidth: baseUnit * 22          // 面板宽度
    readonly property real panelPadding: baseUnit * 0.8       // 面板内边距
    readonly property real panelRadius: baseUnit * 0.15       // 面板圆角
    readonly property real panelGap: baseUnit * 0.15          // 面板内元素间距
    readonly property real panelOffsetY: baseUnit * 3.3       // 面板Y偏移
    readonly property real panelLabelWidth: baseUnit * 5      // 面板标签宽度
    readonly property real panelRowHeight: baseUnit * 0.9     // 面板行高

    // ═══════════════════════════════════════════════════════
    // 🎚️ L4 · 滑块/进度条
    // ═══════════════════════════════════════════════════════
    readonly property real sliderWidth: baseUnit * 12         // 滑块宽度
    readonly property real sliderHeight: 3                    // 滑块高度
    readonly property real sliderHitArea: 10// 滑块点击区域扩展
    // ═══════════════════════════════════════════════════════
    // 🎬 L5 · 动画配置
    // ═══════════════════════════════════════════════════════
    readonly property int animSpeedNormal: 200
    readonly property int animSpeedFast: 150
    readonly property var animEasing: Easing.OutQuad

    // ═══════════════════════════════════════════════════════
    // 🎨 Cyber-Zen 配色 (带动态兜底逻辑)
    // ═══════════════════════════════════════════════════════
    property color zenVoid: "#0a0a0a"
    property color zenInk: "#141414"
    property color zenStone: "#1f1f1f"
    property color zenMist: "#2a2a2a"
    property color zenAsh: "#3a3a3a"
    property color zenSmoke: "#5a5a5a"
    property color zenCloud: "#8a8a8a"
    property color zenSnow: "#cacaca"
    property color zenPure: "#f0f0f0"
    property color zenAccent: "#5a9a8a"

    // ═══════════════════════════════════════════════════════
    // 📊 系统状态数据
    // ═══════════════════════════════════════════════════════
    property bool systemPanelVisible: false
    property bool centerPanelVisible: false
    property bool centerPanelClosing: false
    property bool systemPanelClosing: false
    property string netSSID: "loading..."
    property string netInterface: "wlo1"
    property string btStatus: "OFF"
    property int volumePercent: 70
    property int brightnessPercent: 50
    // MPRIS 播放器（响应式绑定逻辑，副作用剥离至信号处理器）
    property var lastActivePlayer: null
    readonly property var mprisPlayer: {
        const players = Mpris.players.values;
        if (!players || players.length === 0) return null;

        // 1. 优先选择正在播放的源
        const playing = players.find(p => p.playbackState === MprisPlaybackState.Playing);
        if (playing) return playing;

        // 2. 其次选择记忆中且仍存在的源
        if (root.lastActivePlayer && players.indexOf(root.lastActivePlayer) !== -1) {
            return root.lastActivePlayer;
        }

        // 3. 兜底选择第一个
        return players[0];
    }

    // 在绑定块外部安全更新记忆，防止 Binding Loop
    onMprisPlayerChanged: {
        if (mprisPlayer && mprisPlayer.playbackState === MprisPlaybackState.Playing) {
            if (mprisPlayer !== lastActivePlayer) {
                root.lastActivePlayer = mprisPlayer;
            }
        }
    }

    property string mediaTitle: mprisPlayer?.trackTitle ?? "No Media"
    property string mediaArtist: mprisPlayer?.trackArtists?.join(", ") 
    property bool mediaPlaying: mprisPlayer?.playbackState === MprisPlaybackState.Playing
    property real mediaPosition: 0
    Timer {
        id: mediaSyncTimer
        interval: 500
        running: root.mediaPlaying
        repeat: true
        onTriggered: {
            if (root.mprisPlayer) {
                // QuickShell 的 position 已经是秒为单位，无需除以一百万
                root.mediaPosition = root.mprisPlayer.position
            }
        }
    }
    function formatTime(s) {
        if (!s || s < 0) return "00:00"
        let totalSeconds = Math.floor(s) // 已经是秒单位
        let mins = Math.floor(totalSeconds / 60)
        let secs = totalSeconds % 60
        return (mins < 10 ? "0" + mins : mins) + ":" + (secs < 10 ? "0" + secs : secs)
    }
    property string gpuInfo: "loading..."
    property string nvmeUsage: "0%"
    property string loadAvg: "0.00"
    property int processCount: 0
    property real memTotal: 32.0
    property real memUsed: 0.0
    property string kernelVer: "loading..."
    property string cpuModel: "loading..."
    property string uptime: "0h"

    // 中岛音量反馈代理
    property var centerIslandRef: null
    property int lastVolume: 70
    property int rawVolumePercent: 70

    function refreshPanelData() {
        netProc.running = true
        btProc.running = true
        volProc.running = true
        briProc.running = true
    }

    // Data Processes
    Process {
        id: netProc
        running: true
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.split(":")
                if (parts[1] === "802-11-wireless") {
                    root.netSSID = parts[0] || "Disconnected"
                }
            }
        }
    }
    Process {
        id: btProc
        command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo 'ON' || echo 'OFF'"]
        stdout: SplitParser { onRead: data => root.btStatus = data.trim() }
    }
    Process {
        id: volProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}'"]
        stdout: SplitParser {
            onRead: data => {
                let raw = parseInt(data) || 0
                root.rawVolumePercent = raw
                root.volumePercent = Math.min(raw, 100)
            }
        }
    }
    Process {
        id: briProc
        command: ["sh", "-c", "brightnessctl -m | cut -d, -f4 | tr -d '%' 2>/dev/null || echo 50"]
        stdout: SplitParser { onRead: data => root.brightnessPercent = parseInt(data) || 50 }
    }
    // 媒体数据已通过 MPRIS 服务自动同步，无需轮询

    // Control Processes
    Process { id: volSetProc; command: ["echo"] }
    Process { id: briSetProc; command: ["echo"] }
    // 媒体控制已改用 MPRIS 原生方法

    // System Panel Processes
    Process {
        id: gpuProc
        command: ["sh", "-c", "lspci | grep -i vga | cut -d: -f3 | head -1 | xargs"]
        stdout: SplitParser { onRead: data => root.gpuInfo = data.trim() || "Unknown" }
    }
    Process {
        id: nvmeProc
        command: ["sh", "-c", "df -h / | awk 'NR==2 {print $5}'"]
        stdout: SplitParser { onRead: data => root.nvmeUsage = data.trim() || "0%" }
    }
    Process {
        id: loadProc
        command: ["sh", "-c", "cat /proc/loadavg | cut -d' ' -f1"]
        stdout: SplitParser { onRead: data => root.loadAvg = data.trim() || "0.00" }
    }
    Process {
        id: procCountProc
        command: ["sh", "-c", "ps aux | wc -l"]
        stdout: SplitParser { onRead: data => root.processCount = parseInt(data) || 0 }
    }
    Process {
        id: memTotalProc
        command: ["sh", "-c", "free -g | awk 'NR==2 {print $2}'"]
        stdout: SplitParser { onRead: data => root.memTotal = parseFloat(data) || 32 }
    }
    Process {
        id: memUsedProc
        command: ["sh", "-c", "free -g | awk 'NR==2 {print $3}'"]
        stdout: SplitParser { onRead: data => root.memUsed = parseFloat(data) || 0 }
    }
    Process {
        id: kernelProc
        command: ["sh", "-c", "uname -r"]
        stdout: SplitParser { onRead: data => root.kernelVer = data.trim() }
    }
    Process {
        id: cpuModelProc
        command: ["cat", "/proc/cpuinfo"]
        stdout: SplitParser { 
            onRead: data => {
                if (data.includes("model name") && root.cpuModel === "loading...") {
                    root.cpuModel = data.split(":")[1].trim()
                }
            }
        }
    }
    Process {
        id: uptimeProc
        command: ["sh", "-c", "uptime -p | sed 's/up //' | cut -d, -f1"]
        stdout: SplitParser { onRead: data => root.uptime = data.trim() }
    }

    function refreshSystemData() {
        gpuProc.running = true
        nvmeProc.running = true
        loadProc.running = true
        procCountProc.running = true
        memTotalProc.running = true
        memUsedProc.running = true
        kernelProc.running = true
        cpuModelProc.running = true
        uptimeProc.running = true
    }

    // 🎨 动态配色加载引擎
    property string colorFilePath: "file:///home/shiyi/.cache/matugen/colors.json"
    property string lastColorFileMtime: ""
    
    function applyDynamicColors(fileContent) {
        try {
            var data = JSON.parse(fileContent);
            var c = data.colors;
            
            root.zenVoid = c.surface;
            root.zenInk = c.surface_container;
            root.zenAccent = c.primary;
            root.zenSnow = c.on_surface;
            root.zenMist = c.outline_variant;
            
            root.zenStone = Qt.lighter(root.zenInk, 1.15);
            root.zenAsh = Qt.darker(root.zenSnow, 1.8);
            root.zenSmoke = Qt.darker(root.zenSnow, 2.5);
            root.zenCloud = Qt.darker(root.zenSnow, 1.3);
            
            console.log("[shell] Dynamic colors applied: primary=" + c.primary);} catch (e) {
            console.log("[shell] Dynamic colors parse failed: " + e);
        }
    }
    
    // 延迟读取 Timer（避免竞态条件）
    Timer {
        id: delayedColorRead
        interval: 150
        repeat: false
        onTriggered: root.applyDynamicColors(colorFileView.text())
    }

    FileView {
        id: colorFileView
        path: Qt.resolvedUrl(root.colorFilePath)
        watchChanges: true
        
        onFileChanged: {
            this.reload()
            delayedColorRead.start()
        }
        
        onLoadedChanged: {
            if (this.loaded) {
                root.applyDynamicColors(this.text())
            }
        }
        
        onLoadFailed: {
            console.log("[shell] Color file not found, using fallback")}
    }
    
    // 🔄 文件修改时间检测（强制热更新）
    Process {
        id: colorMtimeProc
        command: ["stat", "-c", "%Y", "/home/shiyi/.cache/matugen/colors.json"]
        stdout: SplitParser {
            onRead: data => {
                let newMtime = data.trim()
                if (root.lastColorFileMtime !== "" && newMtime !== root.lastColorFileMtime) {
                    console.log("[shell] Color file mtime changed, forcing reload...")
                    // 关键技巧：先清空再设回，强制 FileView 重新加载
                    root.colorFilePath = ""
                    root.colorFilePath = "file:///home/shiyi/.cache/matugen/colors.json"
                }
                root.lastColorFileMtime = newMtime
            }
        }
    }
    
    Timer {
        id: colorPollTimer
        interval: 2000
        running: true
        repeat: true
        onTriggered: colorMtimeProc.running = true
    }
    // 音量轮询（每300ms检测系统音量变化）
    Timer {
        id: volPollTimer
        interval: 300
        running: true
        repeat: true
        onTriggered: volProc.running = true
    }

    // 音量反馈计时器（2秒后切回时间显示）
    Timer {
        id: volFeedbackTimer
        interval: 2000
        onTriggered: {
            if (root.centerIslandRef) root.centerIslandRef.showVolume = false
        }
    }

    // 音量到顶抖动检测
    property string lastVolMaxTs: ""
    Process {
        id: volMaxCheckProc
        command: ["cat", "/tmp/qs-vol-max"]
        stdout: SplitParser {
            onRead: data => {
                let ts = data.trim()
                if (ts && ts !== root.lastVolMaxTs && root.lastVolMaxTs !== "") {
                    if (root.centerIslandRef) {
                        root.centerIslandRef.showVolume = true
                        root.centerIslandRef.shake()
                        volFeedbackTimer.restart()
                    }
                }
                root.lastVolMaxTs = ts
            }
        }
    }
    Timer {
        id: volMaxPollTimer
        interval: 200
        running: true
        repeat: true
        onTriggered: volMaxCheckProc.running = true
    }

    // 面板自动刷新（展开时每500ms刷新数据）
    Timer {
        id: autoRefreshTimer
        interval: 500
        running: root.centerPanelVisible || root.systemPanelVisible
        repeat: true
        onTriggered: {
            if (root.centerPanelVisible) {
                root.refreshPanelData()
            }
            if (root.systemPanelVisible) root.refreshSystemData()
        }
        Component.onCompleted: {
            root.refreshSystemData()
            root.loadDynamicColors() // 启动时尝试加载动态颜色
        }
    }

    // 监听音量变化，触发中岛反馈
    onVolumePercentChanged: {
        if (root.centerIslandRef) {
            root.centerIslandRef.volume = Math.min(volumePercent, 100)
            root.centerIslandRef.showVolume = true
            volFeedbackTimer.restart()
            root.lastVolume = volumePercent
        }
    }// 监听原始音量，检测到顶抖动
    onRawVolumePercentChanged: {
        if (root.centerIslandRef && rawVolumePercent >= 100 && lastVolume >= 100) {
            root.centerIslandRef.shake()
        }
    }
    Process { id: reloadProc; command: ["sh", "-c", "pkill quickshell; sleep 0.3; quickshell &"] }

    // ===== MAIN BAR =====
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: barWindow
                required property var modelData
                screen: modelData
                anchors {
                    top: true
                    left: true
                    right: true
                }
                implicitHeight: root.islandHeight
                margins.top: root.barMarginTop
                margins.left: root.barMarginSide
                margins.right: root.barMarginSide
                color: "transparent"
                Bar {
                    anchors.fill: parent
                    zenInk: root.zenInk
                    zenMist: root.zenMist
                    zenStone: root.zenStone
                    zenAsh: root.zenAsh
                    zenSmoke: root.zenSmoke
                    zenCloud: root.zenCloud
                    zenSnow: root.zenSnow
                    zenPure: root.zenPure
                    unit: root.baseUnit
                    leftIslandOffsetX: root.leftIslandOffsetX
                    centerIslandOffsetX: root.centerIslandOffsetX
                    rightIslandOffsetX: root.rightIslandOffsetX
                    panelWindow: barWindow
                    Component.onCompleted: root.centerIslandRef = centerIsland
                    onCenterClicked: {
                        console.log("[shell] centerClicked, toggling panel")
                        root.centerPanelVisible = !root.centerPanelVisible
                        if (root.centerPanelVisible) root.refreshPanelData()
                    }
                    onSystemClicked: {
                        console.log("[shell] systemClicked, toggling system panel")
                        root.systemPanelVisible = !root.systemPanelVisible
                        if (root.systemPanelVisible) root.refreshSystemData()
                    }
                }
            }
        }
    }
    // ===== CENTER PANEL WINDOW =====
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: panelWindow
                required property var modelData
                screen: modelData
                visible: root.centerPanelVisible || root.centerPanelClosing
                exclusiveZone: -1
                anchors { top: true; bottom: true; left: true; right: true }
                color: "transparent"

                // 底层：点击外部关闭
                MouseArea {
                    z: 0
                    anchors.fill: parent
                    onClicked: {
                        if (root.centerPanelVisible) {
                            root.centerPanelClosing = true
                            root.centerPanelVisible = false
                            centerPanelCloseTimer.start()
                        }
                    }
                }

                // 上层：Panel 内容
                Rectangle {
                    id: panelBg
                    z: 1
                    x: (panelWindow.width - root.panelWidth) / 2
                    y: root.panelOffsetY
                    width: root.panelWidth
                    height: panelContent.height + root.panelPadding * 2
                    color: root.zenInk
                    border.color: root.zenMist
                    border.width: 1
                    radius: root.panelRadius
                    opacity: root.centerPanelVisible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: root.animSpeedNormal; easing.type: root.animEasing } }

                    // 拦截背景点击，防止穿透到底层关闭
                    MouseArea {
                        anchors.fill: parent
                        propagateComposedEvents: false
                        onPressed: function(mouse) { mouse.accepted = false }
                    }

                    Column {
                        id: panelContent
                        anchors.top: parent.top
                        anchors.topMargin: root.panelPadding
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: root.panelGap

                        // CONNECTIVITY
                        Text { x: root.panelPadding; text: "CONNECTIVITY"; font.pixelSize: root.fontSection; font.letterSpacing: 3; color: root.zenAsh }
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2
                            Text { text: "NETWORK"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth }
                            Text { text: root.netSSID; font.pixelSize: root.fontSecondary; color: root.zenCloud }
                        }
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2
                            Text { text: "INTERFACE"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth }
                            Text { text: root.netInterface; font.pixelSize: root.fontSecondary; color: root.zenCloud }
                        }
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2
                            Text { text: "BLUETOOTH"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth }
                            Text { text: "archshiyi - " + root.btStatus; font.pixelSize: root.fontSecondary; color: root.zenCloud }
                        }
                        Rectangle { x: root.panelPadding; width: parent.width - root.panelPadding * 2; height: 1; color: root.zenMist }

                        // AUDIO / DISPLAY
                        Text { x: root.panelPadding; text: "AUDIO / DISPLAY"; font.pixelSize: root.fontSection; font.letterSpacing: 3; color: root.zenAsh }
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2; spacing: root.panelGap * 3; height: root.panelRowHeight
                            Text { text: "VOL"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth * 0.5; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle {
                                clip: false
                                width: root.sliderWidth; height: root.sliderHeight; color: root.zenMist; anchors.verticalCenter: parent.verticalCenter
                                Rectangle { width: parent.width * Math.min(root.volumePercent / 100, 1.0); height: root.sliderHeight; color: root.zenCloud }
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -root.sliderHitArea; cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        let pct = Math.min(Math.round(mouse.x / parent.width * 100), 100)
                                        let vol = (pct / 100).toFixed(2)  // 70 → "0.70", max 100
                                        volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", vol]
                                        volSetProc.running = true
                                        root.volumePercent = pct
                                        }
                                    }
                            }
                            Text { text: root.volumePercent + "%"; font.pixelSize: root.fontSecondary; color: root.zenCloud; width: root.panelLabelWidth * 0.6; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2; spacing: root.panelGap * 3; height: root.panelRowHeight
                            Text { text: "BRI"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth * 0.5; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle {
                                width: root.sliderWidth; height: root.sliderHeight; color: root.zenMist; anchors.verticalCenter: parent.verticalCenter
                                Rectangle { width: parent.width * root.brightnessPercent / 100; height: root.sliderHeight; color: root.zenCloud }
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -root.sliderHitArea; cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        let pct = Math.round(mouse.x / parent.width * 100)
                                        briSetProc.command = ["brightnessctl", "set", pct + "%"]
                                        briSetProc.running = true
                                        root.brightnessPercent = pct
                                    }
                                }
                            }
                            Text { text: root.brightnessPercent + "%"; font.pixelSize: root.fontSecondary; color: root.zenCloud; width: root.panelLabelWidth * 0.6; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Rectangle { x: root.panelPadding; width: parent.width - root.panelPadding * 2; height: 1; color: root.zenMist }

                        // NOW PLAYING
                        Text { x: root.panelPadding; text: "NOW PLAYING"; font.pixelSize: root.fontSection; font.letterSpacing: 3; color: root.zenAsh }
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2; height: root.baseUnit * 1.8; spacing: root.panelGap * 4
                            Column {
                                width: parent.width - root.baseUnit * 4; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                Text { text: root.mediaTitle; font.pixelSize: root.fontSecondary * 1.1; color: root.zenSnow; width: parent.width; elide: Text.ElideRight }
                                Text {
                                    text: root.formatTime(root.mediaPosition) + ' / ' + root.formatTime(root.mprisPlayer?.length ?? 0)
                                    font.pixelSize: root.fontTiny; color: root.zenCloud
                                }
                                Text { text: root.mediaArtist; font.pixelSize: root.fontTiny; color: root.zenSmoke }
                            }
                            Row {
                                anchors.verticalCenter: parent.verticalCenter; spacing: root.panelGap * 2.5
                                Repeater {
                                    model: ["prev", "play", "next"]
                                    Rectangle {
                                        width: root.baseUnit * 1.1; height: root.baseUnit * 1.1; color: "transparent"; radius: 2
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData === "prev" ? "⏮" : (modelData === "next" ? "⏭" : (root.mediaPlaying ? "⏸" : "▶"))
                                            font.pixelSize: root.fontSecondary; color: root.zenSmoke
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.mprisPlayer) {
                                                    if (modelData === "prev") root.mprisPlayer.previous()
                                                    else if (modelData === "next") root.mprisPlayer.next()
                                                    else root.mprisPlayer.togglePlaying()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Item { width: 1; height: root.panelGap * 2 }
                    }
                }
            }
        }
    }

    // ===== SYSTEM PANEL WINDOW =====
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: sysPanelWindow
                required property var modelData
                screen: modelData
                visible: root.systemPanelVisible || root.systemPanelClosing
                exclusiveZone: -1
                anchors { top: true; bottom: true; left: true; right: true }
                color: "transparent"

                // 底层：点击外部关闭
                MouseArea {
                    z: 0
                    anchors.fill: parent
                    onClicked: {
                        if (root.systemPanelVisible) {
                            root.systemPanelClosing = true
                            root.systemPanelVisible = false
                            systemPanelCloseTimer.start()
                        }
                    }
                }

                // 上层：Panel 内容
                Rectangle {
                    id: sysPanelBg
                    z: 1
                    x: sysPanelWindow.width - root.panelWidth - root.barMarginSide
                    y: root.panelOffsetY
                    width: root.panelWidth
                    height: sysPanelContent.height + root.panelPadding * 2
                    color: root.zenInk
                    border.color: root.zenMist
                    border.width: 1
                    radius: root.panelRadius
                    opacity: root.systemPanelVisible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: root.animSpeedNormal; easing.type: root.animEasing } }

                    // 拦截背景点击，防止穿透到底层关闭
                    MouseArea {
                        anchors.fill: parent
                        propagateComposedEvents: false
                        onPressed: function(mouse) { mouse.accepted = false }
                    }
                    Column {
                        id: sysPanelContent
                        anchors.top: parent.top
                        anchors.topMargin: root.panelPadding
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: root.panelGap

                        // GRAPHICS
                        Text { x: root.panelPadding; text: "GRAPHICS"; font.pixelSize: root.fontSection; font.letterSpacing: 3; color: root.zenAsh }
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2
                            Text { text: "GPU"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth * 0.8 }
                            Text { text: root.gpuInfo; font.pixelSize: root.fontSecondary; color: root.zenCloud; width: parent.width - root.panelLabelWidth; elide: Text.ElideRight }
                        }
                        Rectangle { x: root.panelPadding; width: parent.width - root.panelPadding * 2; height: 1; color: root.zenMist }

                        // STORAGE
                        Text { x: root.panelPadding; text: "STORAGE"; font.pixelSize: root.fontSection; font.letterSpacing: 3; color: root.zenAsh }
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2; spacing: root.panelGap * 3
                            Text { text: "NVME"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth * 0.8 }
                            Rectangle {
                                width: root.sliderWidth * 0.8; height: 4; color: root.zenMist; anchors.verticalCenter: parent.verticalCenter
                                Rectangle { width: parent.width * parseInt(root.nvmeUsage) / 100; height: 4; color: root.zenCloud }}
                            Text { text: root.nvmeUsage; font.pixelSize: root.fontSecondary; color: root.zenCloud }
                        }
                        Rectangle { x: root.panelPadding; width: parent.width - root.panelPadding * 2; height: 1; color: root.zenMist }

                        // PERFORMANCE
                        Text { x: root.panelPadding; text: "PERFORMANCE"; font.pixelSize: root.fontSection; font.letterSpacing: 3; color: root.zenAsh }
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2
                            Text { text: "LOAD"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth * 0.8 }
                            Text { text: root.loadAvg; font.pixelSize: root.fontSecondary; color: root.zenCloud }
                        }
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2
                            Text { text: "PROCS"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth * 0.8 }
                            Text { text: root.processCount; font.pixelSize: root.fontSecondary; color: root.zenCloud }
                        }
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2
                            Text { text: "MEM"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth * 0.8 }
                            Text { text: root.memUsed.toFixed(1) + "G / " + root.memTotal.toFixed(0) + "G"; font.pixelSize: root.fontSecondary; color: root.zenCloud }
                        }
                        Rectangle { x: root.panelPadding; width: parent.width - root.panelPadding * 2; height: 1; color: root.zenMist }

                        // SYSTEM
                        Text { x: root.panelPadding; text: "SYSTEM"; font.pixelSize: root.fontSection; font.letterSpacing: 3; color: root.zenAsh }
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2
                            Text { text: "KERNEL"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth * 0.8 }
                            Text { text: root.kernelVer; font.pixelSize: root.fontSecondary; color: root.zenCloud }
                        }
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2
                            Text { text: "CPU"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth * 0.8 }
                            Text { text: root.cpuModel; font.pixelSize: root.fontSecondary; color: root.zenCloud; width: parent.width - root.panelLabelWidth; elide: Text.ElideRight }
                        }
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2
                            Text { text: "UPTIME"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth * 0.8 }
                            Text { text: root.uptime; font.pixelSize: root.fontSecondary; color: root.zenCloud }
                        }
                        Item { width: 1; height: root.panelGap * 2 }
                    }
                }
            }
        }
    }
}
