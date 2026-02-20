//@ pragma UseQApplication
//1111

// 模块：shell（Quickshell 入口 / 顶层装配）
// 功能：作为 Quickshell 的主入口，统一完成以下职责：
// - 全局尺寸/主题色参数（供 Bar/面板渲染统一使用）
// - 系统状态采集与控制（通过 Quickshell.Io.Process 执行外部命令）
// - 媒体状态读取与控制（通过 Quickshell.Services.Mpris）
// - 动态配色热更新（监听 matugen 生成的 colors.json）
// - 创建顶栏窗口（Bar）与两个弹出面板窗口（中心面板/系统面板）
// 关联功能：
// - Bar.qml：顶栏容器（组合 LeftIsland/CenterIsland/RightIslands）
// - CenterIsland：用于时间显示与音量反馈（通过 centerIslandRef 进行联动）
// - 面板窗口：中心面板使用 components/CenterPanel；系统面板仍在本文件内“内联”构建（待抽离）
// 注意：
// - 外部命令执行依赖系统工具：nmcli/bluetoothctl/wpctl/brightnessctl/pactl/playerctl 等。
// - 为降低开销，音量采用“事件驱动（pactl subscribe）+ 去抖”，亮度采用“低频轮询兜底”。

import Quickshell // ShellRoot/PanelWindow/Variants/screen 枚举等
import Quickshell.Io // Process/SplitParser/FileView：命令执行、流式解析、文件监听
import Quickshell.Services.Mpris // MPRIS：播放器列表与播放状态
import QtQuick // QML 基础类型（Timer/MouseArea/Rectangle/Text/Animation 等）
import "components"

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
    // 🏝️ L1 · 岛屿几何
    // ═══════════════════════════════════════════════════════
    readonly property real islandHeight: baseUnit * 2.0       // 岛屿高度
    readonly property real islandRadius: islandHeight * 0.35  // 岛屿圆角
    readonly property real islandPaddingH: baseUnit * 1.4     // 岛屿水平内边距
    readonly property real islandPaddingV: baseUnit * 0.4     // 岛屿垂直内边距
    readonly property real islandGap: baseUnit * 0.8          // 岛屿之间间距
    readonly property real barMarginTop: baseUnit * 0.2       // 顶栏距屏幕顶部
    readonly property real barMarginSide: baseUnit * 0.2        // 顶栏左右边距（用于避免贴边）
    // 岛屿位置偏移（正值向右，负值向左）
    readonly property real leftIslandOffsetX:   baseUnit * 0    // 左岛X偏移
    readonly property real centerIslandOffsetX: baseUnit * 14    // 中岛 X 偏移（用于整体对齐/构图微调）
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
    readonly property real panelWidth: baseUnit * 30          // 面板宽度
    readonly property real panelPadding: baseUnit * 1       // 面板内边距
    readonly property real panelRadius: baseUnit * 0.15       // 面板圆角
    readonly property real panelGap: baseUnit * 0.15          // 面板内元素间距
    readonly property real panelOffsetY: baseUnit * 2.4       // 面板 Y 偏移（面板从顶栏向下的距离）
    readonly property real panelLabelWidth: baseUnit * 5      // 面板标签宽度
    readonly property real panelRowHeight: baseUnit * 0.9
    readonly property real panelSectionGap: baseUnit * 1.2      // 面板分区间距（盒子之间的距离）
    readonly property real panelRowGap: baseUnit * 0.35         // 面板行间距（盒子内部行距）     // 面板行高

    // ═══════════════════════════════════════════════════════
    // 🎚️ L4 · 滑块/进度条
    // ═══════════════════════════════════════════════════════
    readonly property real sliderHeight: 3                    // 滑块高度
    readonly property real sliderHitArea: 10                // 滑块点击热区扩展（像素；便于小尺寸下操作）
    // ═══════════════════════════════════════════════════════
    // 🎬 L5 · 动画配置
    // ═══════════════════════════════════════════════════════
    readonly property int animSpeedNormal: 200              // 常规动画时长（ms）
    readonly property int animSpeedFast: 150                // 快速动画时长（ms）
    readonly property var animEasing: Easing.OutQuad        // 统一缓动曲线（保持动画风格一致）

    // ═══════════════════════════════════════════════════════
    // 🎨 Cyber-Zen 配色 (带动态兜底逻辑)
    // ═══════════════════════════════════════════════════════
    readonly property color zenVoid: "#050505"
    readonly property color zenInk: "#0a0a0a"
    readonly property color zenStone: "#151515"
    readonly property color zenMist: "#1a1a1a"
    readonly property color zenAsh: "#2a2a2a"
    readonly property color zenSmoke: "#4a4a4a"
    readonly property color zenCloud: "#808080"
    readonly property color zenSnow: "#c0c0c0"
    readonly property color zenPure: "#e0e0e0"
    property color zenAccent: "#5a9a8a"                     // 强调色（频谱专用，保留动态）

    // ═══════════════════════════════════════════════════════
    // 📊 系统状态数据
    // ═══════════════════════════════════════════════════════
    property bool systemPanelVisible: false                 // 系统面板是否可见（用于 window.visible 绑定）
    property bool centerPanelVisible: false                 // 中心面板是否可见（用于 window.visible 绑定）
    property bool centerPanelClosing: false                 // 中心面板“关闭动画期间”的占位可见（避免点击后立刻消失造成事件/动画问题）
    property bool systemPanelClosing: false                 // 系统面板“关闭动画期间”的占位可见
    // 提供给子组件的显式引用（避免组件内出现 undefined / 自引用绑定）
    property alias centerPanelCloseTimer: centerPanelCloseTimer
    property alias systemPanelCloseTimer: systemPanelCloseTimer
    property string netSSID: "loading..."                   // 网络 SSID（由 nmcli 采集）
    property string netInterface: "wlo1"                    // 网络接口名（展示用/占位；当前不随命令自动更新）
    property string btStatus: "OFF"                         // 蓝牙电源状态（ON/OFF；由 bluetoothctl 采集）
    property int volumePercent: 70                          // 音量百分比（0-100；由 wpctl 采集并截断）
    property int brightnessPercent: 50                      // 亮度百分比（0-100；由 brightnessctl 采集）
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
    onMprisPlayerChanged: {
        if (mprisPlayer && mprisPlayer.playbackState === MprisPlaybackState.Playing) {
            if (mprisPlayer !== lastActivePlayer) {
                configRoot.lastActivePlayer = mprisPlayer; // 仅在“正在播放”时更新记忆（避免暂停时抖动）
            }
        }
    }

    property string mediaTitle: mprisPlayer?.trackTitle ?? "No Media" // 当前曲目标题（无播放器/无曲目时回退）
    property string mediaArtist: mprisPlayer?.trackArtists?.join(", ") // 当前曲目艺术家（数组拼接；无时为 undefined）
    property bool mediaPlaying: mprisPlayer?.playbackState === MprisPlaybackState.Playing // 是否播放态（驱动 UI 图标/计时）
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
        var filled = Math.round((pct / 100) * len)
        var bar = ""
        for (var i = 0; i < len; i++) bar += (i < filled ? "█" : "░")
        return "[" + bar + "]"
    }

    property string gpuInfo: "loading..."                    // GPU 信息（由 lspci 采集）
    property string nvmeUsage: "0%"                          // 根分区占用百分比（由 df 采集）
    property string loadAvg: "0.00"                          // 1 分钟 load average（由 /proc/loadavg 采集）
    property int processCount: 0                             // 进程数量（由 ps 采集）
    property real memTotal: 32.0                             // 总内存（GB；由 free -g 采集）
    property real memUsed: 0.0                               // 已用内存（GB；由 free -g 采集）
    property string kernelVer: "loading..."                  // 内核版本（uname -r）
    property string cpuModel: "loading..."                   // CPU 型号（从 /proc/cpuinfo 抽取一次）
    property string uptime: "0h"                             // uptime 简化文本（uptime -p）

    // 中岛音量反馈代理
    property var centerIslandRef: null                       // Bar/CenterIsland 实例引用（用于音量反馈联动）
    property int lastVolume: 70                              // 上一次音量（用于需要差分逻辑时复用；当前主要用于调试/保留）
    property int rawVolumePercent: 70                        // 原始音量百分比（未截断；用于排查 >100% 情况）

    function refreshPanelData() {
        // 输入：无
        // 输出：无返回值
        // 副作用：触发“中心面板”所需数据刷新（网络/蓝牙/亮度）
        // 触发来源：中心面板展开时（onCenterClicked / autoRefreshTimer）

        netProc.running = true // 刷新网络连接信息（SSID）
        btProc.running = true // 刷新蓝牙电源状态
        // 音量已完全移交给事件驱动（pactl subscribe + volProc），中心面板不再主动轮询音量
        briProc.running = true // 刷新亮度信息（亮度仍使用低频轮询兜底）
    }

    // Data Processes（中心面板/顶栏所需的“即时状态”采集）
    Process {
        id: netProc
        running: true // 启动时就采集一次网络连接信息（避免面板首次展开仍是 loading）
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active"] // 输出格式：NAME:TYPE（逐行）
        stdout: SplitParser {
            onRead: data => {
                let parts = data.split(":") // 拆分为 [NAME, TYPE]
                // 逻辑：优先显示 Wi-Fi SSID，如果有线连接存在且当前没有 Wi-Fi，则显示有线名称
                if (parts[1] === "802-11-wireless") {
                    configRoot.netSSID = parts[0] || "Disconnected"
                } else if (parts[1] === "802-3-ethernet" && (configRoot.netSSID === "loading..." || configRoot.netSSID === "Disconnected")) {
                    configRoot.netSSID = parts[0] || "Wired"
                }
            }
        }
    }
    Process {
        id: btProc
        command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo 'ON' || echo 'OFF'"] // 判断蓝牙电源是否开启
        stdout: SplitParser { onRead: data => configRoot.btStatus = data.trim() } // 写回 ON/OFF（驱动 UI）
    }
    Process {
        id: volProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}'"] // 把 0.0~1.0 映射到 0~100
        stdout: SplitParser {
            onRead: data => {
                let raw = parseInt(data) || 0 // 解析音量百分比（可能因解析失败得到 NaN，因此兜底 0）
                configRoot.rawVolumePercent = raw // 记录原始值（便于排查 >100% 的情况）
                configRoot.volumePercent = Math.min(raw, 100) // 对外展示统一截断到 0~100（UI 不显示 >100%）
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
    Process { id: volSetProc; command: ["echo"] } // 占位：设置音量时动态替换为 wpctl set-volume
    Process { id: briSetProc; command: ["echo"] } // 占位：设置亮度时动态替换为 brightnessctl set
    // 媒体控制已改用 MPRIS 原生方法
    // 音量/亮度设置函数（供子组件通过 root.setVolume/root.setBrightness 调用）
    // 解决 QML 名称遮蔽问题：子组件的同名属性会遮蔽 ShellRoot 的 id 引用
    function setVolume(pct) {
        let vol = (pct / 100).toFixed(2)
        volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", vol]
        volSetProc.running = true
        configRoot.volumePercent = pct
    }
    function setBrightness(pct) {
        briSetProc.command = ["brightnessctl", "set", pct + "%"]
        briSetProc.running = true
        configRoot.brightnessPercent = pct
    }


    // System Panel Processes（系统面板展示用状态采集）
    Process {
        id: gpuProc
        command: ["sh", "-c", "lspci | grep -i vga | cut -d: -f3 | head -1 | xargs"] // 取第一条 VGA 控制器描述
        stdout: SplitParser { onRead: data => configRoot.gpuInfo = data.trim() || "Unknown" } // 写回 GPU 文本
    }
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
    Process {
        id: loadProc
        command: ["sh", "-c", "cat /proc/loadavg | cut -d' ' -f1"] // 取 1 分钟 load average
        stdout: SplitParser { onRead: data => configRoot.loadAvg = data.trim() || "0.00" } // 写回 load average
    }
    Process {
        id: procCountProc
        command: ["sh", "-c", "ps aux | wc -l"] // 粗略统计进程行数（包含表头；用于“趋势”而非精确值）
        stdout: SplitParser { onRead: data => configRoot.processCount = parseInt(data) || 0 } // 写回进程数量
    }
    Process {
        id: memTotalProc
        command: ["sh", "-c", "free -g | awk 'NR==2 {print $2}'"] // 取总内存（GB）
        stdout: SplitParser { onRead: data => configRoot.memTotal = parseFloat(data) || 32 } // 写回总内存（解析失败回退 32）
    }
    Process {
        id: memUsedProc
        command: ["sh", "-c", "free -g | awk 'NR==2 {print $3}'"] // 取已用内存（GB）
        stdout: SplitParser { onRead: data => configRoot.memUsed = parseFloat(data) || 0 } // 写回已用内存
    }
    Process {
        id: kernelProc
        command: ["sh", "-c", "uname -r"] // 读取内核版本
        stdout: SplitParser { onRead: data => configRoot.kernelVer = data.trim() } // 写回内核版本字符串
    }
    Process {
        id: cpuModelProc
        command: ["cat", "/proc/cpuinfo"] // 读取 CPU 信息（多行；SplitParser 会逐行回调）
        stdout: SplitParser { 
            onRead: data => {
                if (data.includes("model name") && configRoot.cpuModel === "loading...") { // 仅在首次命中时写入（避免重复覆盖）
                    configRoot.cpuModel = data.split(":")[1].trim() // 提取冒号后面的型号字符串
                }
            }
        }
    }
    Process {
        id: uptimeProc
        command: ["sh", "-c", "uptime -p | sed 's/up //' | cut -d, -f1"] // 取简化 uptime（只保留第一段，如 2 hours）
        stdout: SplitParser { onRead: data => configRoot.uptime = data.trim() } // 写回 uptime 字符串
    }

    function refreshSystemData() {
        // 输入：无
        // 输出：无返回值
        // 副作用：触发“系统面板”所需数据刷新（GPU/存储/负载/进程/内存/系统信息）
        // 触发来源：系统面板展开时（onSystemClicked / autoRefreshTimer / Component.onCompleted）

        gpuProc.running = true // 刷新 GPU 信息
        nvmeProc.running = true // 刷新根分区占用
        loadProc.running = true // 刷新 load average
        procCountProc.running = true // 刷新进程数量
        memTotalProc.running = true // 刷新总内存
        memUsedProc.running = true // 刷新已用内存
        kernelProc.running = true // 刷新内核版本
        cpuModelProc.running = true // 刷新 CPU 型号（首次写入后开销很低）
        uptimeProc.running = true // 刷新 uptime
    }

    // 🎨 动态配色加载引擎
    readonly property string colorFilePath: "file:///home/shiyi/.cache/matugen/colors.json" // matugen 输出的主题色文件（使用 file:// URL）
    
    function applyDynamicColors(fileContent) {
        // 输入：fileContent（colors.json 的完整文本内容）
        // 输出：无返回值
        // 副作用：更新 zen* 主题色属性（驱动 Bar/面板整体换肤）
        // 触发来源：FileView.onLoadedChanged / FileView.onFileChanged（热更新）

        if (!fileContent) return;
        try {
            var data = JSON.parse(fileContent);
            if (!data.colors || !data.colors.primary) return;
            configRoot.zenAccent = data.colors.primary;
            console.log("[shell] Dynamic accent applied: " + data.colors.primary);
        } catch (e) {}
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

    // 面板关闭计时器（修复鼠标锁定 Bug）
    Timer {
        id: centerPanelCloseTimer // 中心面板关闭“缓冲期”定时器（配合 opacity 动画）
        interval: configRoot.animSpeedNormal + 50 // 等动画结束后再清除 closing 标志（多给 50ms 保险）
        onTriggered: configRoot.centerPanelClosing = false // 关闭缓冲期结束：允许 window 彻底不可见
    }
    Timer {
        id: systemPanelCloseTimer // 系统面板关闭“缓冲期”定时器
        interval: configRoot.animSpeedNormal + 50 // 等动画结束后再清除 closing 标志
        onTriggered: configRoot.systemPanelClosing = false // 关闭缓冲期结束
    }

    // 音量反馈计时器（2秒后切回时间显示）
    Timer {
        id: volFeedbackTimer
        interval: 2000 // 音量反馈展示时长（ms）
        onTriggered: {
            if (configRoot.centerIslandRef) configRoot.centerIslandRef.showVolume = false // 到时后隐藏音量布局，回到时间布局
        }
    }

    // 面板自动刷新（展开时每 1s 刷新数据，降低性能消耗）
    Timer {
        id: autoRefreshTimer
        interval: 1000 // 刷新周期（ms）：面板展开时每秒刷新一次
        running: configRoot.centerPanelVisible || configRoot.systemPanelVisible // 仅在任一面板可见时运行（降低后台开销）
        repeat: true // 周期性触发
        onTriggered: {
            if (configRoot.centerPanelVisible) { // 中心面板展开时才刷新其数据
                configRoot.refreshPanelData() // 刷新网络/蓝牙/亮度等
            }
            if (configRoot.systemPanelVisible) configRoot.refreshSystemData() // 系统面板展开时刷新系统信息
        }
        Component.onCompleted: {
            configRoot.refreshSystemData() // 启动后主动采集一次系统信息（避免首次打开系统面板仍是 loading）
            volProc.running = true // 启动后同步一次音量（让中岛反馈与面板默认值一致）
        }
    }


    // 监听音量变化，触发中岛反馈
    onVolumePercentChanged: {
        if (configRoot.centerIslandRef) { // 只有拿到 CenterIsland 实例引用时才做联动
            configRoot.centerIslandRef.volume = Math.min(volumePercent, 100) // 写入音量数值（确保不超过 100）
            configRoot.centerIslandRef.showVolume = true // 切换到音量反馈布局
            volFeedbackTimer.restart() // 重置“回到时间显示”的计时
            configRoot.lastVolume = volumePercent // 记录上一次音量（可用于后续差分/调试）
        }
    }

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
                implicitHeight: configRoot.islandHeight // 顶栏高度（与岛屿高度一致）
                margins.top: configRoot.barMarginTop // 距离屏幕顶部的留白
                margins.left: configRoot.barMarginSide // 左边距
                margins.right: configRoot.barMarginSide // 右边距
                color: "transparent" // 窗口透明，实际视觉由 Bar/岛屿绘制
                Bar {
                    anchors.fill: parent // Bar 填充整个窗口
                    zenInk: configRoot.zenInk // 主题色注入：背景
                    zenMist: configRoot.zenMist // 主题色注入：边框
                    zenStone: configRoot.zenStone // 主题色注入：hover
                    zenAsh: configRoot.zenAsh // 主题色注入：弱标题
                    zenSmoke: configRoot.zenSmoke // 主题色注入：弱文本
                    zenCloud: configRoot.zenCloud // 主题色注入：中等文本
                    zenSnow: configRoot.zenSnow // 主题色注入：高对比文本
                    zenPure: configRoot.zenPure // 主题色注入：备用亮色
                    zenAccent: configRoot.zenAccent // 主题色注入：强调色
                    unit: configRoot.baseUnit // 尺寸基准注入
                    leftIslandOffsetX: configRoot.leftIslandOffsetX // 位置偏移注入：左岛
                    centerIslandOffsetX: configRoot.centerIslandOffsetX // 位置偏移注入：中岛
                    rightIslandOffsetX: configRoot.rightIslandOffsetX // 位置偏移注入：右岛
                    panelWindow: barWindow // 把窗口引用传给 Bar（供托盘菜单锚点使用）
                    Component.onCompleted: configRoot.centerIslandRef = centerIsland // 记录 CenterIsland 实例（用于音量反馈联动）
                    onCenterClicked: {
                        console.log("[shell] centerClicked, toggling panel") // 调试日志：记录点击
                        configRoot.centerPanelVisible = !configRoot.centerPanelVisible // 切换中心面板可见性
                        if (configRoot.centerPanelVisible) configRoot.refreshPanelData() // 打开时立刻刷新数据（避免陈旧）
                    }
                    onSystemClicked: {
                        console.log("[shell] systemClicked, toggling system panel") // 调试日志：记录点击
                        configRoot.systemPanelVisible = !configRoot.systemPanelVisible // 切换系统面板可见性
                        if (configRoot.systemPanelVisible) configRoot.refreshSystemData() // 打开时立刻刷新数据
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
                id: centerPanelWindow
                required property var modelData
                screen: modelData
                visible: configRoot.centerPanelVisible || configRoot.centerPanelClosing
                exclusiveZone: -1
                anchors { top: true; bottom: true; left: true; right: true }
                color: "transparent"

                // 底层：点击外部关闭
                MouseArea {
                    z: 0
                    anchors.fill: parent
                    onClicked: {
                        if (configRoot.centerPanelVisible) {
                            configRoot.centerPanelClosing = true
                            configRoot.centerPanelVisible = false
                            configRoot.centerPanelCloseTimer.start()
                        }
                    }
                }

                CenterPanel {
                    root: configRoot
                    centerPanelCloseTimer: configRoot.centerPanelCloseTimer

                    centerPanelVisible: configRoot.centerPanelVisible
                    centerPanelClosing: configRoot.centerPanelClosing

                    // 核心重构：真正的相对绑定。直接使用中岛的实时坐标，无视复杂的布局计算
                    panelX: (configRoot.centerIslandRef ? (configRoot.centerIslandRef.x + configRoot.centerIslandRef.width / 2) : (modelData.width / 2)) - configRoot.panelWidth / 2

                    animEasing: configRoot.animEasing
                    animSpeedNormal: configRoot.animSpeedNormal
                    baseUnit: configRoot.baseUnit
                    brightnessPercent: configRoot.brightnessPercent
                    btStatus: configRoot.btStatus
                    fontSecondary: configRoot.fontSecondary
                    fontSection: configRoot.fontSection
                    fontTiny: configRoot.fontTiny
                    mediaArtist: configRoot.mediaArtist
                    mediaPlaying: configRoot.mediaPlaying
                    mediaPosition: configRoot.mediaPosition
                    mediaTitle: configRoot.mediaTitle
                    mprisPlayer: configRoot.mprisPlayer
                    netInterface: configRoot.netInterface
                    netSSID: configRoot.netSSID
                    panelGap: configRoot.panelGap
                    panelLabelWidth: configRoot.panelLabelWidth
                    panelOffsetY: configRoot.panelOffsetY
                    panelPadding: configRoot.panelPadding
                    panelRadius: configRoot.panelRadius
                    panelRowHeight: configRoot.panelRowHeight
                    panelRowGap: configRoot.panelRowGap
                    panelSectionGap: configRoot.panelSectionGap
                    panelWidth: configRoot.panelWidth
                    sliderHeight: configRoot.sliderHeight
                    sliderHitArea: configRoot.sliderHitArea
                    volumePercent: configRoot.volumePercent
                    zenAsh: configRoot.zenAsh
                    zenCloud: configRoot.zenCloud
                    zenInk: configRoot.zenInk
                    zenMist: configRoot.zenMist
                    zenSmoke: configRoot.zenSmoke
                    zenSnow: configRoot.zenSnow
                }
            }
        }
    }
    // ===== SYSTEM PANEL WINDOW =====
    Variants {
        model: Quickshell.screens // 多屏支持：为每个 screen 创建一套“系统面板”窗口（全屏透明层 + 右侧面板）
        delegate: Component {
            PanelWindow {
                id: sysPanelWindow
                required property var modelData // Variants 委托注入：当前 screen 对象
                screen: modelData // 将窗口绑定到当前屏幕
                visible: configRoot.systemPanelVisible || configRoot.systemPanelClosing // 可见条件：打开或处于关闭动画缓冲期
                exclusiveZone: -1 // 不占用布局保留区（允许窗口覆盖全屏）
                anchors { top: true; bottom: true; left: true; right: true } // 覆盖全屏：用于捕获“点击外部关闭”
                color: "transparent" // 窗口透明：只显示面板本体

                // 底层：点击外部关闭
                MouseArea {
                    z: 0 // 底层：在面板之下，用于捕获空白处点击
                    anchors.fill: parent // 覆盖整个窗口（全屏）
                    onClicked: {
                        if (configRoot.systemPanelVisible) {
                            configRoot.systemPanelClosing = true // 进入关闭缓冲期（让动画/事件有时间完成）
                            configRoot.systemPanelVisible = false // 关闭面板“打开态”
                            configRoot.systemPanelCloseTimer.start() // 启动定时器：动画结束后清除 closing 标志
                        }
                    }
                }

                // 上层：Panel 内容
                SystemPanel {
                    root: configRoot
                    systemPanelCloseTimer: configRoot.systemPanelCloseTimer

                    systemPanelVisible: configRoot.systemPanelVisible
                    systemPanelClosing: configRoot.systemPanelClosing

                    barMarginSide: configRoot.barMarginSide
                    panelGap: configRoot.panelGap
                    panelLabelWidth: configRoot.panelLabelWidth
                    panelOffsetY: configRoot.panelOffsetY
                    panelPadding: configRoot.panelPadding
                    panelRadius: configRoot.panelRadius
                    panelWidth: configRoot.panelWidth
                    panelRowHeight: configRoot.panelRowHeight
                    panelRowGap: configRoot.panelRowGap
                    panelSectionGap: configRoot.panelSectionGap

                    fontSecondary: configRoot.fontSecondary
                    fontSection: configRoot.fontSection
                    fontTiny: configRoot.fontTiny

                    gpuInfo: configRoot.gpuInfo
                    nvmeUsage: configRoot.nvmeUsage
                    loadAvg: configRoot.loadAvg
                    processCount: configRoot.processCount
                    memTotal: configRoot.memTotal
                    memUsed: configRoot.memUsed
                    kernelVer: configRoot.kernelVer
                    cpuModel: configRoot.cpuModel
                    uptime: configRoot.uptime

                    zenVoid: configRoot.zenVoid
                    zenInk: configRoot.zenInk
                    zenStone: configRoot.zenStone
                    zenMist: configRoot.zenMist
                    zenAsh: configRoot.zenAsh
                    zenSmoke: configRoot.zenSmoke
                    zenCloud: configRoot.zenCloud
                    zenSnow: configRoot.zenSnow
                    zenPure: configRoot.zenPure
                    zenAccent: configRoot.zenAccent
                }
            }
        }
    }
}
