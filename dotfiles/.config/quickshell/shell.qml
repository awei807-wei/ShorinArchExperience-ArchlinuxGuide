//@ pragma UseQApplication
//1111

// 模块：shell（Quickshell 入口 / 顶层装配）
// 功能：作为 Quickshell 的主入口，统一完成以下职责：
// - 全局尺寸/主题色参数（供 Bar/面板渲染统一使用）
// - 系统状态采集与控制（通过 Quickshell.Io.Process 执行外部命令）
// - 媒体状态读取与控制（通过 Quickshell.Services.Mpris）
// - 动态配色热更新（监听 matugen 生成的 colors.json）
// - 创建顶栏窗口（Bar）、通知面板与右侧控制中心
// 关联功能：
// - Bar.qml：顶栏容器（组合 ContextIsland/ClockIsland/SystemIsland）
// - ClockIsland：用于时间显示与轻量音量反馈（通过 centerIslandRef 联动）
// - 右侧控制中心：使用 components/ImportedControlCenterPanel
// 注意：
// - 外部命令执行依赖系统工具：nmcli/bluetoothctl/wpctl/brightnessctl/pactl/playerctl 等。
// - 为降低开销，音量采用“事件驱动（pactl subscribe）+ 去抖”，亮度采用“低频轮询兜底”。

import Quickshell // ShellRoot/PanelWindow/Variants/screen 枚举等
import Quickshell.Io // Process/SplitParser/FileView：命令执行、流式解析、文件监听
import Quickshell.Services.Mpris // MPRIS：播放器列表与播放状态
import Quickshell.Services.Notifications // Freedesktop 通知接收服务（后续用于接管 mako）
import Quickshell.Services.Pipewire // PipeWire：输出设备枚举与默认 sink 切换
import QtQuick // QML 基础类型（Timer/MouseArea/Rectangle/Text/Animation 等）
import QtMultimedia // QML 原生音频播放（通知音效，无需外部二进制依赖）
import "." as Core
import "components"
import "config" as Config
import "components/AudioOutputModel.js" as AudioOutputModel
import "components/TrayNotificationModel.js" as TrayModel

ShellRoot { // Quickshell 的顶层根对象（负责创建窗口与全局状态）
    id: configRoot

    // ═══════════════════════════════════════════════════════
    // 🎛️ 主控参数 - 只需要调这一个
    // ═══════════════════════════════════════════════════════
    readonly property real k: 6.6                    // UI 缩放主控参数：k 越大 baseUnit 越小（UI 越小）

    // ═══════════════════════════════════════════════════════
    // 📐 L0 · 基准单位（自动计算）
    // ═══════════════════════════════════════════════════════
    readonly property real ppi: 144                // 屏幕 PPI（用于把抽象 unit 映射到像素；可按设备校准）
    readonly property real baseUnit: Math.round(ppi / k) // 全局尺寸基准（所有间距/字号等都以它为基础）

    // ═══════════════════════════════════════════════════════
    // 🏝️ L1 · 顶栏几何
    // 所有 Bar 位置、宽度、字号与内部间距统一在 config/BarTuning.qml 手动调整。
    // ═══════════════════════════════════════════════════════
    readonly property real islandHeight: Config.BarTuning.islandHeight
    readonly property real barHeight: Config.BarTuning.barHeight
    readonly property real trayPowerGap: Config.BarTuning.trayPowerGap
    readonly property int trayDirectIconLimit: 3              // 折叠态直接显示的托盘应用图标上限
    readonly property real barMarginTop: Config.BarTuning.barMarginTop
    readonly property real barMarginSide: Config.BarTuning.barMarginSide
    readonly property real leftIslandOffsetX: Config.BarTuning.leftIslandOffsetX
    readonly property real centerIslandOffsetX: Config.BarTuning.centerIslandOffsetX
    readonly property real rightIslandOffsetX: Config.BarTuning.rightIslandOffsetX

    // ═══════════════════════════════════════════════════════
    // 📦 L3 · 子面板
    // ═══════════════════════════════════════════════════════
    readonly property real notificationPopupWidth: baseUnit * 18 // 临时通知浮窗宽度
    readonly property int notificationMaxVisible: 4              // 临时通知最多同时显示条数

    // ═══════════════════════════════════════════════════════
    // 🎬 L5 · 动画配置
    // ═══════════════════════════════════════════════════════
    readonly property int animSpeedNormal: 200              // 常规动画时长（ms）

    // ═══════════════════════════════════════════════════════
    // 🎨 Cyber-Zen 配色 (带动态兜底逻辑)
    // ═══════════════════════════════════════════════════════
    readonly property color zenVoid: "#080808"               // 最深底色：用于极暗背景/外层遮罩
    readonly property color zenInk: "#101010"                // 主背景色：Bar/面板主体底色
    readonly property color zenStone: "#1c1c1c"              // 悬停底色：hover 时的背景提升
    readonly property color zenMist: "#252525"               // 边框/分割线：用于描边和细分隔
    readonly property color zenAsh: "#404040"                // 弱标题/弱边框：低对比辅助信息
    readonly property color zenSmoke: "#707070"              // 弱文本：次要文字/图标
    readonly property color zenCloud: "#999999"              // 中等文本：常规信息
    readonly property color zenSnow: "#d0d0d0"               // 高对比文本：主要内容
    readonly property color zenPure: "#ffffff"               // 备用亮色：需要更亮的强调文本/图标
    property color zenAccent: "#5a9a8a"                      // 强调色：进度条/关键状态（支持动态热更新）
    readonly property color zenDanger: "#9a5555"             // 通知数字与清理动作的低饱和危险色

    // ═══════════════════════════════════════════════════════
    // 📊 系统状态数据
    // ═══════════════════════════════════════════════════════
    property bool colorParseErrorLogged: false             // 动态配色解析错误只记录一次
    // 提供给子组件的显式引用（避免组件内出现 undefined / 自引用绑定）
    property string netSSID: "loading..."                   // 网络 SSID（由 nmcli 采集）
    property string netInterface: "wlo1"                    // 网络接口名（展示用/占位；当前不随命令自动更新）
    property string networkType: "disconnected"             // ethernet / wifi / disconnected
    property string networkDevice: ""                       // 当前活动网络设备名
    property bool wifiAvailable: false                       // 系统是否存在 Wi-Fi 设备
    property bool wifiEnabled: true                          // Wi-Fi 射频状态（控制中心开关）
    property bool bluetoothAvailable: false                  // 系统是否存在可用蓝牙控制器
    property string btStatus: "OFF"                         // 蓝牙电源状态（ON/OFF；由 bluetoothctl 采集）
    property real volumePercent: 70                         // 音量百分比（保留小数以支持连续拖动）
    property bool volumeMuted: false                        // 默认输出设备静音状态
    readonly property bool audioOutputsReady: Pipewire.ready
    readonly property var audioOutputOptions: AudioOutputModel.options(Pipewire.nodes.values)
    readonly property var activeAudioOutput: Pipewire.defaultAudioSink
        || Pipewire.preferredDefaultAudioSink
    readonly property int audioOutputCurrentIndex: AudioOutputModel.currentIndex(
        audioOutputOptions, activeAudioOutput)
    readonly property string audioOutputPlaceholder: !Pipewire.ready
        ? "SYNCING AUDIO" : audioOutputOptions.length === 0 ? "NO OUTPUT" : "SELECT OUTPUT"
    property int brightnessPercent: 50                      // 亮度百分比（0-100；由 brightnessctl 采集）
    property int notificationCount: 0                       // 已接收到的通知数量（用于验证通知接入链路）
    property var activeNotifications: []                    // 当前正在临时浮窗中展示的通知对象队列
    property var notificationGroups: []           // 按 app 分组的通知（增量更新，避免 Repeater 全量重建闪烁）
    function addNotificationToGroups(notification) {
        // 输入：Quickshell Notification 对象
        // 输出：无返回值
        // 副作用：把通知增量插入对应 app 分组（去重 by id；维护 critical 标记；触发一次属性变更通知）

        const appName = configRoot.cleanNotificationText(notification.appName || "Notification")
        const key = appName.toLowerCase()
        const groups = TrayModel.removeReplacedNotificationFromGroups(
            configRoot.notificationGroups, notification)

        let groupIndex = -1
        for (let i = 0; i < groups.length; ++i) {
            const group = groups[i]
            if (String(group.appName || "").toLowerCase() === key) {
                groupIndex = i
                break
            }
        }

        if (groupIndex === -1) {
            groups.push({
                "appName": appName,
                "notifications": [notification],
                "critical": notification.urgency === NotificationUrgency.Critical
            })
        } else {
            const oldGroup = groups[groupIndex]
            let notices = oldGroup.notifications.filter(item => item.id !== notification.id)
            notices.push(notification)
            let critical = false
            for (let i = 0; i < notices.length; ++i) {
                if (notices[i].urgency === NotificationUrgency.Critical) {
                    critical = true
                    break
                }
            }
            groups[groupIndex] = { "appName": oldGroup.appName, "notifications": notices, "critical": critical }
        }

        configRoot.notificationGroups = groups
    }
    function removeNotificationFromGroups(notification) {
        // 输入：Quickshell Notification 对象
        // 输出：无返回值
        // 副作用：把通知从对应 app 分组增量移除（空组整体删除；重算 critical；触发一次属性变更通知）

        configRoot.notificationGroups = TrayModel.removeNotificationFromGroupsByIdentity(
            configRoot.notificationGroups, notification)
    }
    // MPRIS 播放器（响应式绑定逻辑，副作用剥离至信号处理器）
    property var lastActivePlayer: null                     // 上一次“正在播放”的播放器（用于在暂停时保持来源稳定）
    readonly property var mprisPlayer: {
        // 输出：当前应展示/控制的 MPRIS 播放器对象（或 null）
        // 副作用：无（只读绑定）；记忆更新在 onMprisPlayerChanged 中进行，避免 Binding Loop

        const players = Mpris.players.values; // 当前可用播放器列表（响应式）
        if (!players || players.length === 0) return null; // 没有播放器时返回 null（UI 显示占位）

        // 1. 优先选择正在播放的源
        const playing = players.find(p => p.playbackState === MprisPlaybackState.Playing); // 找到第一个播放态播放器
        if (playing) return playing; // 有播放态则优先使用（符合用户直觉）

        // 2. 其次选择记忆中且仍存在的源
        if (configRoot.lastActivePlayer && players.indexOf(configRoot.lastActivePlayer) !== -1) {
            return configRoot.lastActivePlayer; // 播放器暂停/停止时仍保持上一次来源（避免频繁切换）
        }

        // 3. 兜底选择第一个
        return players[0]; // 最后兜底：选择列表中的第一个播放器
    }

    // 在绑定块外部安全更新记忆，防止 Binding Loop
    // 在绑定块外部安全更新记忆，防止 Binding Loop
    onMprisPlayerChanged: {
        if (mprisPlayer && mprisPlayer.playbackState === MprisPlaybackState.Playing) {
            if (mprisPlayer !== lastActivePlayer) {
                configRoot.lastActivePlayer = mprisPlayer; // 仅在"正在播放"时更新记忆（避免暂停时抖动）
            }
        }
    }

    property string mediaTitle: mprisPlayer?.trackTitle ?? "No Media" // 当前曲目标题（无播放器/无曲目时回退）
    property string mediaArtist: mprisPlayer?.trackArtists?.join(", ") ?? "" // 当前曲目艺术家（数组拼接；无时回退空串）
    property bool mediaPlaying: mprisPlayer?.playbackState === MprisPlaybackState.Playing // 是否播放态（驱动 UI 图标/计时）
    property string mediaArtUrl: mprisPlayer?.trackArtUrl ?? ""     // 当前曲目封面图 URL（MPRIS trackArtUrl；无时回退空串）
    property real mediaPosition: 0                                  // 当前播放位置（秒；由 Timer 同步）
    Timer {
        id: mediaSyncTimer
        interval: 500 // 每 500ms 同步一次播放位置（足够平滑，且开销可控）
        running: configRoot.mediaPlaying // 仅在播放态运行（暂停时不需要更新）
        repeat: true // 周期性触发
        onTriggered: {
            if (configRoot.mprisPlayer) {
                // QuickShell 的 position 已经是秒为单位，无需除以一百万
                configRoot.mediaPosition = configRoot.mprisPlayer.position // 同步当前播放位置（秒）
            }
        }
    }
    function formatTime(s) {
        // 输入：s（秒，允许浮点；来自 MPRIS position）
        // 输出：MM:SS 字符串（用于面板显示）
        // 副作用：无

        if (!s || s < 0) return "00:00" // 非法/空值统一回退为 00:00（避免 NaN/负数显示）
        let totalSeconds = Math.floor(s) // 取整为秒（位置为秒单位，忽略小数部分）
        let mins = Math.floor(totalSeconds / 60) // 计算分钟数
        let secs = totalSeconds % 60 // 计算秒数（0-59）
        return (mins < 10 ? "0" + mins : mins) + ":" + (secs < 10 ? "0" + secs : secs) // 补零并拼接成 MM:SS
    }

    function getAsciiBar(pct, len) {
        // 输入：
        // - pct: 0~100 的百分比（音量/亮度等）
        // - len: 条形长度（字符数量）
        // 输出：形如 "[██░░░]" 的字符串（用于等宽字体展示“伪进度条”）
        // 副作用：无

        var filled = Math.round((pct / 100) * len)
        var bar = ""
        for (var i = 0; i < len; i++) bar += (i < filled ? "█" : "░")
        return "[" + bar + "]"
    }

    function getAsciiBarAuto(pct, widthPx, charWidthPx) {
        // 输入：
        // - pct: 0~100 的百分比
        // - widthPx: 目标显示区域的像素宽度（通常为 Text.width）
        // - charWidthPx: 单个“条形字符”的像素宽度（由 QML TextMetrics 测得）
        // 输出：按可用宽度动态决定 len 的伪进度条字符串
        // 副作用：无

        var cw = Math.max(1, Math.round(charWidthPx || 0)) // 防止 0/NaN 导致除零
        var w = Math.max(0, Math.round(widthPx || 0))
        var len = Math.floor(w / cw) - 2 // 预留 '[' 与 ']' 两个字符
        if (len < 1) len = 1
        return getAsciiBar(pct, len)
    }

    function cleanNotificationText(value) {
        // 输入：通知标题/正文等文本
        // 输出：单行压缩后的文本，便于日志验证
        // 副作用：无

        return String(value || "").replace(/\s+/g, " ").trim()
    }

    function trackNotification(notification) {
        // 输入：Quickshell Notification 对象
        // 输出：无返回值
        // 副作用：将通知加入临时浮窗队列；被替换或挤出的对象立即 expire

        const replaced = configRoot.activeNotifications.filter(
            item => item !== notification && item.id === notification.id
        )
        let list = configRoot.activeNotifications.filter(item => item.id !== notification.id)
        list.unshift(notification)
        const visible = list.slice(0, configRoot.notificationMaxVisible)
        const dropped = replaced.concat(list.slice(configRoot.notificationMaxVisible))
        configRoot.activeNotifications = visible
        configRoot.addNotificationToGroups(notification) // 增量更新分组（替代全量重算，避免卡片重建闪烁）
        dropped.forEach(item => {
            try {
                item.expire()
            } catch (error) {
                console.warn("[Notifications] failed to expire dropped notification: " + error)
            }
        })
    }

    function untrackNotification(notification) {
        // 输入：Quickshell Notification 对象
        // 输出：无返回值
        // 副作用：从临时浮窗队列移除通知（并增量移出对应分组）

        // 替换通知可能复用同一个 id；旧对象稍后 closed/expire 时只能移除自身，
        // 不能按 id 删除当前仍在活动队列中的新对象。
        configRoot.activeNotifications = TrayModel.removeNotificationByIdentity(
            configRoot.activeNotifications, notification)
        configRoot.removeNotificationFromGroups(notification)
    }

    function notificationIsActive(notification) {
        // 输入：Quickshell Notification 对象
        // 输出：该通知是否在当前可见队列中
        // 副作用：无

        return configRoot.activeNotifications.some(item => item.id === notification.id)
    }

    function focusNotificationSource(notification) {
        // 输入：Quickshell Notification 对象
        // 输出：无返回值
        // 副作用：尝试让 niri 聚焦通知来源应用的窗口；无匹配窗口时静默忽略

        notificationFocusProc.command = [
            "bash",
            "/home/shiyi/.config/quickshell/scripts/focus-notification-source.sh",
            notification.desktopEntry || "",
            notification.appName || "",
            notification.summary || ""
        ]
        notificationFocusProc.running = true
    }

    // 🔔 通知音效（QML 原生 SoundEffect，无需外部二进制依赖）
    SoundEffect {
        id: notificationSound
        source: Qt.resolvedUrl("file:///home/shiyi/.config/quickshell/music.wav")
        volume: 0.7 // 音量 0.0~1.0
    }

    NotificationHistoryStore {
        id: notificationHistoryStore
        onHistoryCleared: {
            if (rightPanelController.page === rightPanelController.notificationsPage)
                rightPanelController.close()
        }
        onOperationFailed: (operation, message) => console.warn(
            "[NotificationHistory] " + operation + " failed: " + message
        )
    }

    RightPanelController {
        id: rightPanelController
        reducedMotion: Core.TopBarState.reducedMotion
    }

    NotificationServer {
        id: notificationServer
        keepOnReload: false // 只验证新进入的通知，避免 reload 后重复处理旧通知
        bodySupported: true // 告诉客户端可以传递正文
        bodyMarkupSupported: false // 当前只做接收验证，先不声明支持富文本渲染
        actionsSupported: true // 分组通知展开后提供原生通知操作按钮
        imageSupported: false // 当前未做图片展示，先不声明支持图片能力
        inlineReplySupported: false // 当前未做行内回复

        onNotification: notification => {
            // Notification QObject 只服务于临时浮窗；历史记录先压平为纯 JSON 快照。
            const appName = configRoot.cleanNotificationText(notification.appName)
            const summary = configRoot.cleanNotificationText(notification.summary)
            const urgency = NotificationUrgency.toString(notification.urgency)
            notificationHistoryStore.appendSnapshot({
                "id": notification.id,
                "appName": notification.appName || "",
                "desktopEntry": notification.desktopEntry || "",
                "summary": notification.summary || "",
                "body": notification.body || "",
                "urgency": urgency,
                "timestamp": Date.now()
            })

            notification.tracked = true

            configRoot.notificationCount += 1
            configRoot.trackNotification(notification)

            console.log("[Notifications] received #" + configRoot.notificationCount
                        + " id=" + notification.id
                        + " app=\"" + appName + "\""
                        + " summary=\"" + summary + "\""
                        + " urgency=" + urgency)

            notificationSound.play() // 播放通知音效（QML 原生，无外部依赖）

            notification.closed.connect(function(reason) {
                configRoot.untrackNotification(notification)
                console.log("[Notifications] closed id=" + notification.id
                            + " reason=" + NotificationCloseReason.toString(reason))
            })
        }
    }

    property string nvmeUsage: "0%"                          // 根分区占用百分比（由 df 采集）

    // 时钟岛音量反馈代理
    property var centerIslandRef: null                       // Bar/ClockIsland 实例引用（兼容音量反馈联动）
    property int lastVolume: 70                              // 上一次音量（用于需要差分逻辑时复用；当前主要用于调试/保留）
    property real rawVolumePercent: 70                       // 原始音量百分比（未截断；用于排查 >100% 情况）
    property real requestedVolumePercent: 70                 // 滑块最新请求值
    property real appliedVolumePercent: 70                   // 最近一次已提交给 wpctl 的值

    function refreshControlData() {
        // 输入：无
        // 输出：无返回值
        // 副作用：刷新右侧控制中心使用的网络、蓝牙和亮度状态
        // 触发来源：控制中心打开或执行控制操作后

        netProc.running = true // 刷新网络连接信息（SSID）
        wifiStatusProc.running = true // 刷新 Wi-Fi 射频状态
        btProc.running = true // 刷新蓝牙电源状态
        // 音量已完全移交给事件驱动（pactl subscribe + volProc），无需主动轮询
        briProc.running = true // 刷新亮度信息（亮度仍使用低频轮询兜底）
    }

    function applyNetworkState(rawText) {
        const lines = String(rawText || "").trim().split("\n").filter(line => line.length > 0)
        let wifiFound = false
        let chosenType = "disconnected"
        let chosenDevice = ""
        let chosenName = "Disconnected"

        for (const line of lines) {
            const parts = line.split(":")
            const device = parts[0] || ""
            const type = parts[1] || ""
            const state = parts[2] || ""
            const connection = parts.slice(3).join(":").replace(/\\:/g, ":")

            if (type === "wifi")
                wifiFound = true
            if (state !== "connected")
                continue

            if (type === "ethernet") {
                chosenType = "ethernet"
                chosenDevice = device
                chosenName = connection || device || "Ethernet"
            } else if (type === "wifi" && chosenType !== "ethernet") {
                chosenType = "wifi"
                chosenDevice = device
                chosenName = connection || device || "Wi-Fi"
            }
        }

        configRoot.wifiAvailable = wifiFound
        configRoot.networkType = chosenType
        configRoot.networkDevice = chosenDevice
        configRoot.netInterface = chosenDevice || configRoot.netInterface
        configRoot.netSSID = chosenName
        console.log("[Network] type=" + chosenType + " device=" + chosenDevice
                    + " wifiAvailable=" + wifiFound + " name=" + chosenName)
    }

    // Data Processes（中心面板/顶栏所需的“即时状态”采集）
    Process {
        id: netProc
        running: true // 启动时就采集一次网络连接信息（避免面板首次展开仍是 loading）
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]
        stdout: StdioCollector { id: netStateOutput; waitForEnd: true }
        onExited: configRoot.applyNetworkState(netStateOutput.text)
    }
    Process {
        id: wifiStatusProc
        running: true
        command: ["nmcli", "radio", "wifi"]
        stdout: SplitParser {
            onRead: data => configRoot.wifiEnabled = data.trim() === "enabled"
        }
    }
    Process {
        id: btProc
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector { id: bluetoothStateOutput; waitForEnd: true }
        onExited: (exitCode, exitStatus) => {
            const output = String(bluetoothStateOutput.text || "")
            configRoot.bluetoothAvailable = exitCode === 0 && output.includes("Controller ")
            configRoot.btStatus = configRoot.bluetoothAvailable && output.includes("Powered: yes") ? "ON" : "OFF"
            console.log("[Bluetooth] available=" + configRoot.bluetoothAvailable
                        + " powered=" + (configRoot.btStatus === "ON"))
        }
    }
    Process {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                const match = data.match(/Volume:\s+([0-9.]+)/)
                let raw = match ? parseFloat(match[1]) * 100 : 0
                configRoot.rawVolumePercent = raw // 记录原始值（便于排查 >100% 的情况）
                configRoot.volumePercent = Math.min(raw, 100) // 对外展示统一截断到 0~100（UI 不显示 >100%）
                configRoot.volumeMuted = data.includes("[MUTED]")
            }
        }
    }
    Process {
        id: briProc
        command: ["sh", "-c", "brightnessctl -m | cut -d, -f4 | tr -d '%' 2>/dev/null || echo 50"] // 读取亮度百分比；失败回退 50
        stdout: SplitParser { onRead: data => configRoot.brightnessPercent = parseInt(data) || 50 } // 写回亮度百分比
    }
    // 媒体数据已通过 MPRIS 服务自动同步，无需轮询

    // Control Processes
    Process {
        id: volSetProc
        command: ["echo"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("[Audio] wpctl set-volume failed, exit=" + exitCode)
            volProc.running = true
            if (Math.abs(configRoot.requestedVolumePercent - configRoot.appliedVolumePercent) > 0.05)
                volumeSetTimer.restart()
        }
    }
    Process { id: briSetProc; command: ["echo"] } // 占位：设置亮度时动态替换为 brightnessctl set
    Process {
        id: wifiToggleProc
        command: ["echo"]
        onExited: {
            wifiStatusProc.running = true
            netProc.running = true
        }
    }
    Process {
        id: bluetoothToggleProc
        command: ["echo"]
        onExited: btProc.running = true
    }
    Process {
        id: muteToggleProc
        command: ["echo"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("[Audio] wpctl set-mute failed, exit=" + exitCode)
            volProc.running = true
        }
    }
    Timer {
        id: volumeSetTimer
        interval: 35
        repeat: false
        onTriggered: {
            if (volSetProc.running) {
                restart()
                return
            }
            configRoot.appliedVolumePercent = configRoot.requestedVolumePercent
            volSetProc.command = [
                "wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@",
                (configRoot.appliedVolumePercent / 100).toFixed(3)
            ]
            volSetProc.running = true
        }
    }
    Process {
        id: idleBootstrapProc
        running: true // 启动主壳时统一接管 swayidle，确保 30/40/60 策略与状态文件生效
        command: ["sh", "-lc", "$HOME/.config/quickshell/scripts/idle-control.sh start >/dev/null 2>&1"]
    }
    Process { id: notificationFocusProc; command: ["echo"] } // 通知点击时动态替换为聚焦来源窗口脚本
    // 媒体控制已改用 MPRIS 原生方法
    // 音量/亮度设置函数（供子组件通过 root.setVolume/root.setBrightness 调用）
    // 解决 QML 名称遮蔽问题：子组件的同名属性会遮蔽 ShellRoot 的 id 引用
    function setVolume(pct) {
        // 输入：pct（0~100 的整数百分比）
        // 输出：无返回值
        // 副作用：
        // - 调用 wpctl 设置默认输出设备音量
        // - 立即更新 volumePercent（让 UI 即时响应；真实值随后会被 volProc 校正）

        const value = Math.max(0, Math.min(100, Number(pct) || 0))
        configRoot.requestedVolumePercent = value
        configRoot.volumePercent = value
        volumeSetTimer.restart()
    }
    function setBrightness(pct) {
        // 输入：pct（0~100 的整数百分比）
        // 输出：无返回值
        // 副作用：
        // - 调用 brightnessctl 设置背光亮度
        // - 立即更新 brightnessPercent（让 UI 即时响应；真实值随后会被 briProc 校正）

        briSetProc.command = ["brightnessctl", "set", pct + "%"]
        briSetProc.running = true
        configRoot.brightnessPercent = pct
    }
    function toggleMute() {
        muteToggleProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        muteToggleProc.running = true
        configRoot.volumeMuted = !configRoot.volumeMuted
        volDebounceTimer.restart()
    }
    function selectAudioOutput(index) {
        // 输入：audioOutputOptions 中的索引
        // 输出：无返回值
        // 副作用：更新 PipeWire 首选默认输出，并刷新该默认 sink 的音量/静音状态

        const option = configRoot.audioOutputOptions[index]
        if (!option || !AudioOutputModel.isOutputNode(option.node)) {
            console.warn("[Audio] ignored invalid output selection index=" + index)
            return
        }

        Pipewire.preferredDefaultAudioSink = option.node
        console.log("[Audio] preferred output=" + option.label + " id=" + option.id)
        volDebounceTimer.restart()
    }
    function toggleWifi() {
        if (!configRoot.wifiAvailable || configRoot.networkType === "ethernet")
            return
        const enable = !configRoot.wifiEnabled
        wifiToggleProc.command = ["nmcli", "radio", "wifi", enable ? "on" : "off"]
        wifiToggleProc.running = true
        configRoot.wifiEnabled = enable
        if (!enable)
            configRoot.netSSID = "Wi-Fi off"
    }
    function toggleBluetooth() {
        if (!configRoot.bluetoothAvailable)
            return
        const enable = configRoot.btStatus !== "ON"
        bluetoothToggleProc.command = ["bluetoothctl", "power", enable ? "on" : "off"]
        bluetoothToggleProc.running = true
        configRoot.btStatus = enable ? "ON" : "OFF"
    }


    // 右侧控制中心磁盘占用采集
    Process {
        id: nvmeProc
        command: ["df", "-h", "/"]
        stdout: SplitParser { onRead: data => {
            if (data.startsWith("/")) {
                var p = data.trim().split(/\s+/)
                if (p.length >= 5) configRoot.nvmeUsage = p[4] + " [" + p[2] + " / " + p[1] + "]"
            }
        }}
    }
    function refreshDiskData() {
        nvmeProc.running = true
    }

    // 🎨 动态配色加载引擎
    readonly property string colorFilePath: "file:///home/shiyi/.cache/matugen/colors.json" // matugen 输出的主题色文件（使用 file:// URL）
    
    function applyDynamicColors(fileContent) {
        // 输入：fileContent（colors.json 的完整文本内容）
        // 输出：无返回值
        // 副作用：更新 zenAccent（向后兼容）+ Config.Theme 单例颜色 token（带 300ms 平滑过渡，驱动 Bar/面板整体换肤）
        // 触发来源：FileView.onLoadedChanged / FileView.onFileChanged（热更新）
        // matugen 字段 → Theme token 映射：
        //   primary→accent  surface→surface  on_surface→textPrimary
        //   outline→textSecondary  surface_container→surfaceContainer
        //   outline_variant→outline  secondary→accentSecondary  tertiary→accentTertiary
        // （textMuted / danger / outlineVariant 保留静态兜底）

        if (!fileContent) return;
        try {
            var data = JSON.parse(fileContent);
            var c = data.colors;
            if (!c || !c.primary) return;
            configRoot.zenAccent = c.primary; // 向后兼容：原有 zen* 属性保留不动
            var theme = Config.Theme;
            if (c.primary) theme.accent = c.primary;
            if (c.surface) theme.surface = c.surface;
            if (c.on_surface) theme.textPrimary = c.on_surface;
            if (c.outline) theme.textSecondary = c.outline;
            if (c.surface_container) theme.surfaceContainer = c.surface_container;
            if (c.outline_variant) theme.outline = c.outline_variant;
            if (c.secondary) theme.accentSecondary = c.secondary;
            if (c.tertiary) theme.accentTertiary = c.tertiary;
            console.log("[shell] Dynamic theme applied: accent=" + c.primary);
        } catch (error) {
            if (!configRoot.colorParseErrorLogged) {
                configRoot.colorParseErrorLogged = true
                console.warn("[shell] invalid dynamic color payload: " + error)
            }
        }
    }
    
    Timer {
        id: delayedColorRead
        interval: 200 // 延迟读取：用于避免“写文件中途触发”导致读到半截 JSON
        repeat: false // 单次触发
        onTriggered: configRoot.applyDynamicColors(colorFileView.text()) // 读取 FileView 当前文本并应用配色
    }

    FileView {
        id: colorFileView
        path: Qt.resolvedUrl(configRoot.colorFilePath) // 解析为绝对 URL（避免相对路径解析问题）
        watchChanges: true // 开启文件变更监听（inotify）
        
        // 简化热更新：watchChanges 触发时 reload，reload 触发 onLoadedChanged
        onFileChanged: {
            this.reload() // 主动重新加载文件内容（更新 this.text()/loaded）
            delayedColorRead.start() // 延迟应用一次（减少半截 JSON 的概率）
        }
        
        onLoadedChanged: {
            if (this.loaded) {
                configRoot.applyDynamicColors(this.text()) // 文件已成功加载时立刻应用（首次加载/手动 reload）
            }
        }
        
        onLoadFailed: {
            console.log("[shell] Color file not found, using fallback")
        }
    }

    // 音量同步防抖器：防止频繁信号导致进程堆叠
    Timer {
        id: volDebounceTimer
        interval: 150 // 去抖窗口（ms）：把连续事件合并为一次刷新
        repeat: false // 单次触发（由 restart() 重置计时）
        onTriggered: volProc.running = true // 到点后触发一次音量采集（wpctl）
    }

    // 全链路音量事件驱动：仅监听 Sink（物理输出）变更
    Process {
        id: volSubscribeProc
        running: true // 常驻运行：持续监听 PulseAudio/PipeWire 事件
        command: ["pactl", "subscribe"] // 输出类似：Event 'change' on sink #xx
        stdout: SplitParser {
            onRead: data => {
                // 仅在 sink（输出设备）发生 change 事件时触发刷新
                if (data.includes("'change' on sink")) {
                    volDebounceTimer.restart() // 收到事件后重置去抖计时（避免短时间内启动过多 wpctl）
                }
            }
        }
    }

    // 亮度依然没有标准的轻量级监听机制，保留低频轮询作为兜底
    Timer {
        id: briPollTimer
        interval: 2000 // 2 秒轮询一次（亮度变化不要求高实时性）
        running: true // 常驻运行（提供兜底刷新）
        repeat: true // 周期性触发
        onTriggered: briProc.running = true // 触发一次亮度采集（brightnessctl）
    }

    // 音量反馈计时器（2秒后切回时间显示）
    Timer {
        id: volFeedbackTimer
        interval: 2000 // 音量反馈展示时长（ms）
        onTriggered: {
            if (configRoot.centerIslandRef) configRoot.centerIslandRef.showVolume = false // 到时后隐藏音量布局，回到时间布局
        }
    }

    Component.onCompleted: {
        configRoot.refreshControlData()
        configRoot.refreshDiskData()
        volProc.running = true
    }


    // 监听音量变化，触发中岛反馈
    onVolumePercentChanged: {
        if (configRoot.centerIslandRef) { // 只有拿到 ClockIsland 实例引用时才做联动
            configRoot.centerIslandRef.volume = Math.min(volumePercent, 100) // 写入音量数值（确保不超过 100）
            configRoot.centerIslandRef.showVolume = true // 切换到音量反馈布局
            volFeedbackTimer.restart() // 重置“回到时间显示”的计时
            configRoot.lastVolume = volumePercent // 记录上一次音量（可用于后续差分/调试）
        }
    }

    onActiveAudioOutputChanged: volDebounceTimer.restart()

    // 监听到顶信号文件（事件驱动版：基于 inotify）
    FileView {
        id: volMaxFileView
        path: "file:///tmp/qs-vol-max" // 约定：外部脚本在“音量到顶”时 touch/写入该文件以触发提示
        watchChanges: true // 开启文件变更监听（inotify）
        onFileChanged: {
            // 收到 inotify 信号，强制唤起音量条并触发反馈
            if (configRoot.centerIslandRef) {
                configRoot.centerIslandRef.volume = 100 // 强制显示 100%（语义：到顶）
                configRoot.centerIslandRef.showVolume = true // 切换到音量反馈布局
                configRoot.centerIslandRef.shake() // 触发抖动动画（增强提示）
                volFeedbackTimer.restart() // 重启计时器，确保音量条持续显示一段时间
            }
        }
    }
    // 已废弃 reloadProc，现在使用 FileView 动态热更新配色，无需重启进程
    Process { id: reloadProc; command: ["echo", "QuickShell: Dynamic colors updated via FileView."] } // 占位：保留旧接口以避免引用缺失

    // ===== MAIN BAR =====
    Variants {
        model: Quickshell.screens // 多屏支持：为每个 screen 创建一套顶栏窗口
        delegate: Component {
            PanelWindow {
                id: barWindow
                required property var modelData // Variants 委托注入：当前 screen 对象
                screen: modelData // 将窗口绑定到当前屏幕
                anchors {
                    top: true // 贴顶
                    left: true // 贴左
                    right: true // 贴右（形成整条顶栏）
                }
                implicitHeight: configRoot.barHeight // 顶部连接带与下伸岛体共同占用的顶栏高度
                margins.top: configRoot.barMarginTop // 距离屏幕顶部的留白
                margins.left: configRoot.barMarginSide // 左边距
                margins.right: configRoot.barMarginSide // 右边距
                color: "transparent" // 窗口透明，实际视觉由 Bar/岛屿绘制
                Bar {
                    anchors.fill: parent // Bar 填充整个窗口
                    root: configRoot
                    zenInk: configRoot.zenInk // 主题色注入：背景
                    zenMist: configRoot.zenMist // 主题色注入：边框
                    zenStone: configRoot.zenStone // 主题色注入：hover
                    zenAsh: configRoot.zenAsh // 主题色注入：弱标题
                    zenSmoke: configRoot.zenSmoke // 主题色注入：弱文本
                    zenCloud: configRoot.zenCloud // 主题色注入：中等文本
                    zenSnow: configRoot.zenSnow // 主题色注入：高对比文本
                    zenPure: configRoot.zenPure // 主题色注入：备用亮色
                    zenAccent: configRoot.zenAccent // 主题色注入：强调色
                    zenDanger: configRoot.zenDanger // 主题色注入：通知徽标与清理动作
                    unit: configRoot.baseUnit // 尺寸基准注入
                    panelWindow: barWindow // 把窗口引用传给 Bar（供托盘菜单锚点使用）
                    trayDirectIconLimit: configRoot.trayDirectIconLimit
                    notificationHistoryCount: notificationHistoryStore.historyCount
                    notificationSourceCounts: notificationHistoryStore.sourceCounts
                    // History 只切换壳内页面，不再把全部托盘图标向左展开；
                    // 关闭态和打开态都维持 304px 颈部内的紧凑内容。
                    trayPanelExpanded: false
                    rightPanelOpen: rightPanelController.open
                    Component.onCompleted: configRoot.centerIslandRef = centerIsland // 记录 ClockIsland 实例（用于音量反馈联动）
                    onSystemClicked: {
                        rightPanelController.togglePage(rightPanelController.controlsPage)
                        if (rightPanelController.open
                                && rightPanelController.page === rightPanelController.controlsPage) {
                            configRoot.refreshControlData()
                            configRoot.refreshDiskData()
                        }
                    }
                    onTrayPanelToggleRequested: () => {
                        rightPanelController.togglePage(rightPanelController.notificationsPage)
                    }
                    onTrayPanelCloseRequested: {
                        if (rightPanelController.page === rightPanelController.notificationsPage)
                            rightPanelController.close()
                    }
                }
            }
        }
    }

    ScreenEdgeBorderHost {
        shellRoot: configRoot
    }

    RightPanelHost {
        shellRoot: configRoot
        controller: rightPanelController
        store: notificationHistoryStore
    }

    // ===== TEMP NOTIFICATION POPUPS =====
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: notificationWindow
                required property var modelData
                screen: modelData
                visible: configRoot.activeNotifications.length > 0
                exclusiveZone: -1
                anchors { top: true; right: true }
                margins.top: configRoot.barMarginTop + configRoot.barHeight + configRoot.baseUnit * 0.5
                margins.right: configRoot.barMarginSide + configRoot.baseUnit * 0.4
                implicitWidth: configRoot.notificationPopupWidth
                implicitHeight: notificationColumn.implicitHeight
                color: "transparent" // 窗口透明，实际视觉由通知卡片绘制

                Column {
                    id: notificationColumn
                    width: parent.width
                    spacing: configRoot.baseUnit * 0.35

                    // 通知消失后下方分组平滑上移（替代瞬移）
                    move: Transition {
                        NumberAnimation {
                            properties: "y"
                            duration: Config.Theme.animNormal
                            easing.type: Easing.OutCubic
                        }
                    }

                    Repeater {
                        id: notificationGroupRepeater
                        model: configRoot.notificationGroups

                        NotificationPopupGroup {
                            required property var modelData
                            required property int index
                            width: notificationColumn.width
                            group: modelData
                            unit: configRoot.baseUnit
                            ink: configRoot.zenInk
                            stone: configRoot.zenStone
                            mist: configRoot.zenMist
                            smoke: configRoot.zenSmoke
                            cloud: configRoot.zenCloud
                            snow: configRoot.zenSnow
                            onDismissRequested: notice => notice.dismiss()
                            onSourceRequested: notice => configRoot.focusNotificationSource(notice)

                            // 退场动画期间先把对应通知从分组数据中移除（触发剩余分组重排），
                            // 动画播放完后清掉占位计数，卡片真正销毁，避免闪烁/复用错位。
                            onExitStarted: notification => {
                                notificationColumn.exitCleanupPending += 1
                                configRoot.removeNotificationFromGroups(notification)
                            }
                            onExitFinished: notificationColumn.exitCleanupPending -= 1
                        }
                    }

                    // 退场动画播放期间临时保留对应数量的已移除卡片（占位防闪）
                    // 说明：repeater.model 保持绑定分组数组，不要在这里覆盖；
                    // 任务E的"占位"语义由卡片自身退出动画承担，无需改 model。
                    property int exitCleanupPending: 0
                }
            }
        }
    }

}
