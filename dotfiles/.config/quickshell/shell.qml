//@ pragma UseQApplication

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
// - 面板窗口：在本文件内“内联”构建 UI（并非使用 components/CenterPanel/SystemPanel）
// 注意：
// - 外部命令执行依赖系统工具：nmcli/bluetoothctl/wpctl/brightnessctl/pactl/playerctl 等。
// - 为降低开销，音量采用“事件驱动（pactl subscribe）+ 去抖”，亮度采用“低频轮询兜底”。

import Quickshell // ShellRoot/PanelWindow/Variants/screen 枚举等
import Quickshell.Io // Process/SplitParser/FileView：命令执行、流式解析、文件监听
import Quickshell.Services.Mpris // MPRIS：播放器列表与播放状态
import QtQuick // QML 基础类型（Timer/MouseArea/Rectangle/Text/Animation 等）

ShellRoot { // Quickshell 的顶层根对象（负责创建窗口与全局状态）
    id: root

    // ═══════════════════════════════════════════════════════
    // 🎛️ 主控参数 - 只需要调这一个
    // ═══════════════════════════════════════════════════════
    readonly property real k: 6                    // UI 缩放主控参数：k 越大 baseUnit 越小（UI 越小）

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
    readonly property real barMarginTop: baseUnit * 0.8       // 顶栏距屏幕顶部
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
    readonly property real panelWidth: baseUnit * 22          // 面板宽度
    readonly property real panelPadding: baseUnit * 0.8       // 面板内边距
    readonly property real panelRadius: baseUnit * 0.15       // 面板圆角
    readonly property real panelGap: baseUnit * 0.15          // 面板内元素间距
    readonly property real panelOffsetY: baseUnit * 3       // 面板 Y 偏移（面板从顶栏向下的距离）
    readonly property real panelLabelWidth: baseUnit * 5      // 面板标签宽度
    readonly property real panelRowHeight: baseUnit * 0.9     // 面板行高

    // ═══════════════════════════════════════════════════════
    // 🎚️ L4 · 滑块/进度条
    // ═══════════════════════════════════════════════════════
    readonly property real sliderWidth: baseUnit * 12         // 滑块宽度
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
    property color zenVoid: "#0a0a0a"                       // 备用极深色（用于更深背景/阴影）
    property color zenInk: "#141414"                        // 主背景色（岛屿底色/面板底色）
    property color zenStone: "#1f1f1f"                      // hover 背景色（比 zenInk 略亮）
    property color zenMist: "#2a2a2a"                       // 边框/分割线色（弱对比）
    property color zenAsh: "#3a3a3a"                        // 分区标题等弱文本色
    property color zenSmoke: "#5a5a5a"                      // 图标/弱文本色
    property color zenCloud: "#8a8a8a"                      // 数值/中等文本色
    property color zenSnow: "#cacaca"                       // 高对比文本色
    property color zenPure: "#f0f0f0"                       // 备用更亮色（极少使用）
    property color zenAccent: "#5a9a8a"                     // 强调色（进度条/频谱条等）

    // ═══════════════════════════════════════════════════════
    // 📊 系统状态数据
    // ═══════════════════════════════════════════════════════
    property bool systemPanelVisible: false                 // 系统面板是否可见（用于 window.visible 绑定）
    property bool centerPanelVisible: false                 // 中心面板是否可见（用于 window.visible 绑定）
    property bool centerPanelClosing: false                 // 中心面板“关闭动画期间”的占位可见（避免点击后立刻消失造成事件/动画问题）
    property bool systemPanelClosing: false                 // 系统面板“关闭动画期间”的占位可见
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
        if (root.lastActivePlayer && players.indexOf(root.lastActivePlayer) !== -1) {
            return root.lastActivePlayer; // 播放器暂停/停止时仍保持上一次来源（避免频繁切换）
        }

        // 3. 兜底选择第一个
        return players[0]; // 最后兜底：选择列表中的第一个播放器
    }

    // 在绑定块外部安全更新记忆，防止 Binding Loop
    onMprisPlayerChanged: {
        if (mprisPlayer && mprisPlayer.playbackState === MprisPlaybackState.Playing) {
            if (mprisPlayer !== lastActivePlayer) {
                root.lastActivePlayer = mprisPlayer; // 仅在“正在播放”时更新记忆（避免暂停时抖动）
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
        running: root.mediaPlaying // 仅在播放态运行（暂停时不需要更新）
        repeat: true // 周期性触发
        onTriggered: {
            if (root.mprisPlayer) {
                // QuickShell 的 position 已经是秒为单位，无需除以一百万
                root.mediaPosition = root.mprisPlayer.position // 同步当前播放位置（秒）
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
                if (parts[1] === "802-11-wireless") { // 仅关心 Wi-Fi 连接（忽略有线等）
                    root.netSSID = parts[0] || "Disconnected" // 写回 SSID（空值回退）
                }
            }
        }
    }
    Process {
        id: btProc
        command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo 'ON' || echo 'OFF'"] // 判断蓝牙电源是否开启
        stdout: SplitParser { onRead: data => root.btStatus = data.trim() } // 写回 ON/OFF（驱动 UI）
    }
    Process {
        id: volProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}'"] // 把 0.0~1.0 映射到 0~100
        stdout: SplitParser {
            onRead: data => {
                let raw = parseInt(data) || 0 // 解析音量百分比（可能因解析失败得到 NaN，因此兜底 0）
                root.rawVolumePercent = raw // 记录原始值（便于排查 >100% 的情况）
                root.volumePercent = Math.min(raw, 100) // 对外展示统一截断到 0~100（UI 不显示 >100%）
            }
        }
    }
    Process {
        id: briProc
        command: ["sh", "-c", "brightnessctl -m | cut -d, -f4 | tr -d '%' 2>/dev/null || echo 50"] // 读取亮度百分比；失败回退 50
        stdout: SplitParser { onRead: data => root.brightnessPercent = parseInt(data) || 50 } // 写回亮度百分比
    }
    // 媒体数据已通过 MPRIS 服务自动同步，无需轮询

    // Control Processes
    Process { id: volSetProc; command: ["echo"] } // 占位：设置音量时动态替换为 wpctl set-volume
    Process { id: briSetProc; command: ["echo"] } // 占位：设置亮度时动态替换为 brightnessctl set
    // 媒体控制已改用 MPRIS 原生方法

    // System Panel Processes（系统面板展示用状态采集）
    Process {
        id: gpuProc
        command: ["sh", "-c", "lspci | grep -i vga | cut -d: -f3 | head -1 | xargs"] // 取第一条 VGA 控制器描述
        stdout: SplitParser { onRead: data => root.gpuInfo = data.trim() || "Unknown" } // 写回 GPU 文本
    }
    Process {
        id: nvmeProc
        command: ["sh", "-c", "df -h / | awk 'NR==2 {print $5}'"] // 取根分区使用率（如 42%）
        stdout: SplitParser { onRead: data => root.nvmeUsage = data.trim() || "0%" } // 写回占用百分比
    }
    Process {
        id: loadProc
        command: ["sh", "-c", "cat /proc/loadavg | cut -d' ' -f1"] // 取 1 分钟 load average
        stdout: SplitParser { onRead: data => root.loadAvg = data.trim() || "0.00" } // 写回 load average
    }
    Process {
        id: procCountProc
        command: ["sh", "-c", "ps aux | wc -l"] // 粗略统计进程行数（包含表头；用于“趋势”而非精确值）
        stdout: SplitParser { onRead: data => root.processCount = parseInt(data) || 0 } // 写回进程数量
    }
    Process {
        id: memTotalProc
        command: ["sh", "-c", "free -g | awk 'NR==2 {print $2}'"] // 取总内存（GB）
        stdout: SplitParser { onRead: data => root.memTotal = parseFloat(data) || 32 } // 写回总内存（解析失败回退 32）
    }
    Process {
        id: memUsedProc
        command: ["sh", "-c", "free -g | awk 'NR==2 {print $3}'"] // 取已用内存（GB）
        stdout: SplitParser { onRead: data => root.memUsed = parseFloat(data) || 0 } // 写回已用内存
    }
    Process {
        id: kernelProc
        command: ["sh", "-c", "uname -r"] // 读取内核版本
        stdout: SplitParser { onRead: data => root.kernelVer = data.trim() } // 写回内核版本字符串
    }
    Process {
        id: cpuModelProc
        command: ["cat", "/proc/cpuinfo"] // 读取 CPU 信息（多行；SplitParser 会逐行回调）
        stdout: SplitParser { 
            onRead: data => {
                if (data.includes("model name") && root.cpuModel === "loading...") { // 仅在首次命中时写入（避免重复覆盖）
                    root.cpuModel = data.split(":")[1].trim() // 提取冒号后面的型号字符串
                }
            }
        }
    }
    Process {
        id: uptimeProc
        command: ["sh", "-c", "uptime -p | sed 's/up //' | cut -d, -f1"] // 取简化 uptime（只保留第一段，如 2 hours）
        stdout: SplitParser { onRead: data => root.uptime = data.trim() } // 写回 uptime 字符串
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

        if (!fileContent) return; // 空内容直接忽略（避免 JSON.parse 抛错）
        try {
            var data = JSON.parse(fileContent); // 解析 matugen 生成的 JSON
            if (!data.colors) return; // 结构不符合预期则忽略
            var c = data.colors; // 提取 colors 字段（减少后续访问层级）
            
            root.zenVoid = c.surface; // 深色基底
            root.zenInk = c.surface_container; // 主背景色（岛屿/面板底色）
            root.zenAccent = c.primary; // 强调色（进度条/频谱等）
            root.zenSnow = c.on_surface; // 高对比前景色（文本）
            root.zenMist = c.outline_variant; // 边框/分割线色
            
            root.zenStone = Qt.lighter(root.zenInk, 1.15); // hover 背景：在主背景上提亮
            root.zenAsh = Qt.darker(root.zenSnow, 1.8); // 弱标题色：在文本色上压暗
            root.zenSmoke = Qt.darker(root.zenSnow, 2.5); // 更弱文本色：进一步压暗
            root.zenCloud = Qt.darker(root.zenSnow, 1.3); // 中等文本色：轻微压暗
            
            console.log("[shell] Dynamic colors applied: primary=" + c.primary); // 调试日志：记录主题已更新
        } catch (e) {
            // 忽略半截 JSON 导致的解析错误
        }
    }
    
    Timer {
        id: delayedColorRead
        interval: 200 // 延迟读取：用于避免“写文件中途触发”导致读到半截 JSON
        repeat: false // 单次触发
        onTriggered: root.applyDynamicColors(colorFileView.text()) // 读取 FileView 当前文本并应用配色
    }

    FileView {
        id: colorFileView
        path: Qt.resolvedUrl(root.colorFilePath) // 解析为绝对 URL（避免相对路径解析问题）
        watchChanges: true // 开启文件变更监听（inotify）
        
        // 简化热更新：watchChanges 触发时 reload，reload 触发 onLoadedChanged
        onFileChanged: {
            this.reload() // 主动重新加载文件内容（更新 this.text()/loaded）
            delayedColorRead.start() // 延迟应用一次（减少半截 JSON 的概率）
        }
        
        onLoadedChanged: {
            if (this.loaded) {
                root.applyDynamicColors(this.text()) // 文件已成功加载时立刻应用（首次加载/手动 reload）
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
        interval: root.animSpeedNormal + 50 // 等动画结束后再清除 closing 标志（多给 50ms 保险）
        onTriggered: root.centerPanelClosing = false // 关闭缓冲期结束：允许 window 彻底不可见
    }
    Timer {
        id: systemPanelCloseTimer // 系统面板关闭“缓冲期”定时器
        interval: root.animSpeedNormal + 50 // 等动画结束后再清除 closing 标志
        onTriggered: root.systemPanelClosing = false // 关闭缓冲期结束
    }

    // 音量反馈计时器（2秒后切回时间显示）
    Timer {
        id: volFeedbackTimer
        interval: 2000 // 音量反馈展示时长（ms）
        onTriggered: {
            if (root.centerIslandRef) root.centerIslandRef.showVolume = false // 到时后隐藏音量布局，回到时间布局
        }
    }

    // 面板自动刷新（展开时每 1s 刷新数据，降低性能消耗）
    Timer {
        id: autoRefreshTimer
        interval: 1000 // 刷新周期（ms）：面板展开时每秒刷新一次
        running: root.centerPanelVisible || root.systemPanelVisible // 仅在任一面板可见时运行（降低后台开销）
        repeat: true // 周期性触发
        onTriggered: {
            if (root.centerPanelVisible) { // 中心面板展开时才刷新其数据
                root.refreshPanelData() // 刷新网络/蓝牙/亮度等
            }
            if (root.systemPanelVisible) root.refreshSystemData() // 系统面板展开时刷新系统信息
        }
        Component.onCompleted: {
            root.refreshSystemData() // 启动后主动采集一次系统信息（避免首次打开系统面板仍是 loading）
            volProc.running = true // 启动后同步一次音量（让中岛反馈与面板默认值一致）
            // 修复：移除未定义的 loadDynamicColors 调用，FileView 会在加载时自动触发 apply
        }
    }

    // 监听音量变化，触发中岛反馈
    onVolumePercentChanged: {
        if (root.centerIslandRef) { // 只有拿到 CenterIsland 实例引用时才做联动
            root.centerIslandRef.volume = Math.min(volumePercent, 100) // 写入音量数值（确保不超过 100）
            root.centerIslandRef.showVolume = true // 切换到音量反馈布局
            volFeedbackTimer.restart() // 重置“回到时间显示”的计时
            root.lastVolume = volumePercent // 记录上一次音量（可用于后续差分/调试）
        }
    }

    // 监听到顶信号文件（事件驱动版：基于 inotify）
    FileView {
        id: volMaxFileView
        path: "file:///tmp/qs-vol-max" // 约定：外部脚本在“音量到顶”时 touch/写入该文件以触发提示
        watchChanges: true // 开启文件变更监听（inotify）
        onFileChanged: {
            // 收到 inotify 信号，强制唤起音量条并触发反馈
            if (root.centerIslandRef) {
                root.centerIslandRef.volume = 100 // 强制显示 100%（语义：到顶）
                root.centerIslandRef.showVolume = true // 切换到音量反馈布局
                root.centerIslandRef.shake() // 触发抖动动画（增强提示）
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
                implicitHeight: root.islandHeight // 顶栏高度（与岛屿高度一致）
                margins.top: root.barMarginTop // 距离屏幕顶部的留白
                margins.left: root.barMarginSide // 左边距
                margins.right: root.barMarginSide // 右边距
                color: "transparent" // 窗口透明，实际视觉由 Bar/岛屿绘制
                Bar {
                    anchors.fill: parent // Bar 填充整个窗口
                    zenInk: root.zenInk // 主题色注入：背景
                    zenMist: root.zenMist // 主题色注入：边框
                    zenStone: root.zenStone // 主题色注入：hover
                    zenAsh: root.zenAsh // 主题色注入：弱标题
                    zenSmoke: root.zenSmoke // 主题色注入：弱文本
                    zenCloud: root.zenCloud // 主题色注入：中等文本
                    zenSnow: root.zenSnow // 主题色注入：高对比文本
                    zenPure: root.zenPure // 主题色注入：备用亮色
                    zenAccent: root.zenAccent // 主题色注入：强调色
                    unit: root.baseUnit // 尺寸基准注入
                    leftIslandOffsetX: root.leftIslandOffsetX // 位置偏移注入：左岛
                    centerIslandOffsetX: root.centerIslandOffsetX // 位置偏移注入：中岛
                    rightIslandOffsetX: root.rightIslandOffsetX // 位置偏移注入：右岛
                    panelWindow: barWindow // 把窗口引用传给 Bar（供托盘菜单锚点使用）
                    Component.onCompleted: root.centerIslandRef = centerIsland // 记录 CenterIsland 实例（用于音量反馈联动）
                    onCenterClicked: {
                        console.log("[shell] centerClicked, toggling panel") // 调试日志：记录点击
                        root.centerPanelVisible = !root.centerPanelVisible // 切换中心面板可见性
                        if (root.centerPanelVisible) root.refreshPanelData() // 打开时立刻刷新数据（避免陈旧）
                    }
                    onSystemClicked: {
                        console.log("[shell] systemClicked, toggling system panel") // 调试日志：记录点击
                        root.systemPanelVisible = !root.systemPanelVisible // 切换系统面板可见性
                        if (root.systemPanelVisible) root.refreshSystemData() // 打开时立刻刷新数据
                    }
                }
            }
        }
    }
    // ===== CENTER PANEL WINDOW =====
    Variants {
        model: Quickshell.screens // 多屏支持：为每个 screen 创建一套“中心面板”窗口（全屏透明层 + 居中面板）
        delegate: Component {
            PanelWindow {
                id: panelWindow
                required property var modelData // Variants 委托注入：当前 screen 对象
                screen: modelData // 将窗口绑定到当前屏幕
                visible: root.centerPanelVisible || root.centerPanelClosing // 可见条件：打开或处于关闭动画缓冲期
                exclusiveZone: -1 // 不占用布局保留区（允许窗口覆盖全屏）
                anchors { top: true; bottom: true; left: true; right: true } // 覆盖全屏：用于捕获“点击外部关闭”
                color: "transparent" // 窗口透明：只显示面板本体

                // 底层：点击外部关闭
                MouseArea {
                    z: 0 // 底层：在面板之下，用于捕获空白处点击
                    anchors.fill: parent // 覆盖整个窗口（全屏）
                    onClicked: {
                        if (root.centerPanelVisible) {
                            root.centerPanelClosing = true // 进入关闭缓冲期（让动画/事件有时间完成）
                            root.centerPanelVisible = false // 关闭面板“打开态”
                            centerPanelCloseTimer.start() // 启动定时器：动画结束后清除 closing 标志
                        }
                    }
                }

                // 上层：Panel 内容
                Rectangle {
                    id: panelBg
                    z: 1 // 上层：实际可见的面板本体
                    x: (panelWindow.width - root.panelWidth) / 2 // 面板水平居中
                    y: root.panelOffsetY // 面板距顶部偏移（与顶栏保持视觉间距）
                    width: root.panelWidth // 面板固定宽度
                    height: panelContent.height + root.panelPadding * 2 // 面板高度 = 内容高度 + 上下内边距
                    color: root.zenInk // 面板背景色
                    border.color: root.zenMist // 面板边框色
                    border.width: 1 // 面板边框宽度
                    radius: root.panelRadius // 面板圆角
                    opacity: root.centerPanelVisible ? 1 : 0 // 透明度：用淡入淡出做开关动画
                    Behavior on opacity { NumberAnimation { duration: root.animSpeedNormal; easing.type: root.animEasing } } // 透明度动画

                    // 拦截背景点击，防止穿透到底层关闭
                    MouseArea {
                        anchors.fill: parent // 覆盖面板本体区域
                        propagateComposedEvents: false // 不传播 composed events（减少“穿透”概率）
                        onPressed: function(mouse) { mouse.accepted = false } // 不吞掉 press：让内部控件（滑块/按钮）仍可响应；空白处可能仍被底层关闭层捕获
                    }

                    Column {
                        id: panelContent
                        anchors.top: parent.top // 内容从面板顶部开始布局
                        anchors.topMargin: root.panelPadding // 顶部内边距
                        anchors.left: parent.left // 左对齐
                        anchors.right: parent.right // 右对齐（撑满宽度）
                        spacing: root.panelGap // 行间距（统一控制视觉密度）

                        // CONNECTIVITY
                        Text { x: root.panelPadding; text: "CONNECTIVITY"; font.pixelSize: root.fontSection; font.letterSpacing: 3; color: root.zenAsh } // 分区标题：连接性
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2 // 对齐并预留左右内边距
                            Text { text: "NETWORK"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth } // 标签：网络
                            Text { text: root.netSSID; font.pixelSize: root.fontSecondary; color: root.zenCloud } // 值：SSID/Disconnected
                        }
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2 // 与上一行对齐
                            Text { text: "INTERFACE"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth } // 标签：网卡接口
                            Text { text: root.netInterface; font.pixelSize: root.fontSecondary; color: root.zenCloud } // 值：接口名（当前为静态占位）
                        }
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2 // 与上一行对齐
                            Text { text: "BLUETOOTH"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth } // 标签：蓝牙
                            Text { text: "archshiyi - " + root.btStatus; font.pixelSize: root.fontSecondary; color: root.zenCloud } // 值：蓝牙电源状态（示例前缀 + ON/OFF）
                        }
                        Rectangle { x: root.panelPadding; width: parent.width - root.panelPadding * 2; height: 1; color: root.zenMist } // 分割线

                        // AUDIO / DISPLAY
                        Text { x: root.panelPadding; text: "AUDIO / DISPLAY"; font.pixelSize: root.fontSection; font.letterSpacing: 3; color: root.zenAsh } // 分区标题：音频/显示
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2; spacing: root.panelGap * 3; height: root.panelRowHeight // 一行：音量
                            Text { text: "VOL"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth * 0.5; anchors.verticalCenter: parent.verticalCenter } // 标签：音量
                            Rectangle {
                                clip: false // 不裁剪：允许点击热区 margins 扩展到外侧
                                width: root.sliderWidth; height: root.sliderHeight; color: root.zenMist; anchors.verticalCenter: parent.verticalCenter // 进度条背景
                                Rectangle { width: parent.width * Math.min(root.volumePercent / 100, 1.0); height: root.sliderHeight; color: root.zenCloud } // 进度条填充（0~100）
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -root.sliderHitArea; cursorShape: Qt.PointingHandCursor // 扩大点击热区并提示可点击
                                    onClicked: mouse => {
                                        let pct = Math.min(Math.round(mouse.x / parent.width * 100), 100) // 点击位置映射到 0~100，并限制最大 100
                                        let vol = (pct / 100).toFixed(2)  // 把百分比转为 0.00~1.00（wpctl 需要）
                                        volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", vol] // 组装设置音量命令
                                        volSetProc.running = true // 异步执行设置音量
                                        root.volumePercent = pct // 立即更新 UI（不等待命令回写）
                                    }
                                }
                            }
                            Text { text: root.volumePercent + "%"; font.pixelSize: root.fontSecondary; color: root.zenCloud; width: root.panelLabelWidth * 0.6; anchors.verticalCenter: parent.verticalCenter } // 音量数值
                        }
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2; spacing: root.panelGap * 3; height: root.panelRowHeight // 一行：亮度
                            Text { text: "BRI"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth * 0.5; anchors.verticalCenter: parent.verticalCenter } // 标签：亮度
                            Rectangle {
                                width: root.sliderWidth; height: root.sliderHeight; color: root.zenMist; anchors.verticalCenter: parent.verticalCenter // 进度条背景
                                Rectangle { width: parent.width * root.brightnessPercent / 100; height: root.sliderHeight; color: root.zenCloud } // 进度条填充（0~100）
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -root.sliderHitArea; cursorShape: Qt.PointingHandCursor // 扩大点击热区并提示可点击
                                    onClicked: mouse => {
                                        let pct = Math.round(mouse.x / parent.width * 100) // 点击位置映射到 0~100
                                        briSetProc.command = ["brightnessctl", "set", pct + "%"] // 组装设置亮度命令
                                        briSetProc.running = true // 异步执行设置亮度
                                        root.brightnessPercent = pct // 立即更新 UI（不等待命令回写）
                                    }
                                }
                            }
                            Text { text: root.brightnessPercent + "%"; font.pixelSize: root.fontSecondary; color: root.zenCloud; width: root.panelLabelWidth * 0.6; anchors.verticalCenter: parent.verticalCenter } // 亮度数值
                        }
                        Rectangle { x: root.panelPadding; width: parent.width - root.panelPadding * 2; height: 1; color: root.zenMist } // 分割线

                        // NOW PLAYING
                        Text { x: root.panelPadding; text: "NOW PLAYING"; font.pixelSize: root.fontSection; font.letterSpacing: 3; color: root.zenAsh } // 分区标题：媒体播放
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2; height: root.baseUnit * 1.8; spacing: root.panelGap * 4 // 一行：媒体信息 + 控制按钮
                            Column {
                                width: parent.width - root.baseUnit * 4; anchors.verticalCenter: parent.verticalCenter; spacing: 2 // 左侧信息区（右侧预留按钮空间）
                                Text { text: root.mediaTitle; font.pixelSize: root.fontSecondary * 1.1; color: root.zenSnow; width: parent.width; elide: Text.ElideRight } // 标题（过长省略）
                                Text {
                                    text: root.formatTime(root.mediaPosition) + " / " + root.formatTime(root.mprisPlayer?.length ?? 0) // 进度：当前位置 / 总时长（总时长缺失则 00:00）
                                    font.pixelSize: root.fontTiny; color: root.zenCloud // 辅助信息字号与颜色
                                }
                                Text { text: root.mediaArtist; font.pixelSize: root.fontTiny; color: root.zenSmoke } // 艺术家（弱化显示）
                            }
                            Row {
                                anchors.verticalCenter: parent.verticalCenter; spacing: root.panelGap * 2.5 // 右侧按钮组
                                Repeater {
                                    model: ["prev", "play", "next"] // 三个按钮：上一首/播放暂停/下一首
                                    Rectangle {
                                        width: root.baseUnit * 1.1; height: root.baseUnit * 1.1; color: "transparent"; radius: 2 // 按钮容器（透明背景）
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData === "prev" ? "⏮" : (modelData === "next" ? "⏭" : (root.mediaPlaying ? "⏸" : "▶")) // 根据按钮类型与播放状态选择图标
                                            font.pixelSize: root.fontSecondary; color: root.zenSmoke // 图标字号与颜色
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor // 点击热区覆盖按钮并提示可点击
                                            onClicked: {
                                                if (root.mprisPlayer) { // 只有在存在播放器时才执行控制
                                                    if (modelData === "prev") root.mprisPlayer.previous() // 上一首
                                                    else if (modelData === "next") root.mprisPlayer.next() // 下一首
                                                    else root.mprisPlayer.togglePlaying() // 播放/暂停切换
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Item { width: 1; height: root.panelGap * 2 } // 底部留白（避免内容贴边）
                    }
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
                visible: root.systemPanelVisible || root.systemPanelClosing // 可见条件：打开或处于关闭动画缓冲期
                exclusiveZone: -1 // 不占用布局保留区（允许窗口覆盖全屏）
                anchors { top: true; bottom: true; left: true; right: true } // 覆盖全屏：用于捕获“点击外部关闭”
                color: "transparent" // 窗口透明：只显示面板本体

                // 底层：点击外部关闭
                MouseArea {
                    z: 0 // 底层：在面板之下，用于捕获空白处点击
                    anchors.fill: parent // 覆盖整个窗口（全屏）
                    onClicked: {
                        if (root.systemPanelVisible) {
                            root.systemPanelClosing = true // 进入关闭缓冲期（让动画/事件有时间完成）
                            root.systemPanelVisible = false // 关闭面板“打开态”
                            systemPanelCloseTimer.start() // 启动定时器：动画结束后清除 closing 标志
                        }
                    }
                }

                // 上层：Panel 内容
                Rectangle {
                    id: sysPanelBg
                    z: 1 // 上层：实际可见的面板本体
                    x: sysPanelWindow.width - root.panelWidth - root.barMarginSide // 面板靠右（预留右侧边距）
                    y: root.panelOffsetY // 面板距顶部偏移（与顶栏保持视觉间距）
                    width: root.panelWidth // 面板固定宽度（与中心面板一致）
                    height: sysPanelContent.height + root.panelPadding * 2 // 面板高度 = 内容高度 + 上下内边距
                    color: root.zenInk // 面板背景色
                    border.color: root.zenMist // 面板边框色
                    border.width: 1 // 面板边框宽度
                    radius: root.panelRadius // 面板圆角
                    opacity: root.systemPanelVisible ? 1 : 0 // 透明度：用淡入淡出做开关动画
                    Behavior on opacity { NumberAnimation { duration: root.animSpeedNormal; easing.type: root.animEasing } } // 透明度动画

                    // 拦截背景点击，防止穿透到底层关闭
                    MouseArea {
                        anchors.fill: parent // 覆盖面板本体区域
                        propagateComposedEvents: false // 不传播 composed events（减少“穿透”概率）
                        onPressed: function(mouse) { mouse.accepted = false } // 不吞掉 press：让内部控件仍可响应；空白处可能仍被底层关闭层捕获
                    }
                    Column {
                        id: sysPanelContent
                        anchors.top: parent.top // 内容从面板顶部开始布局
                        anchors.topMargin: root.panelPadding // 顶部内边距
                        anchors.left: parent.left // 左对齐
                        anchors.right: parent.right // 右对齐（撑满宽度）
                        spacing: root.panelGap // 行间距（统一控制视觉密度）

                        // GRAPHICS
                        Text { x: root.panelPadding; text: "GRAPHICS"; font.pixelSize: root.fontSection; font.letterSpacing: 3; color: root.zenAsh } // 分区标题：图形
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2 // 对齐并预留左右内边距
                            Text { text: "GPU"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth * 0.8 } // 标签：GPU
                            Text { text: root.gpuInfo; font.pixelSize: root.fontSecondary; color: root.zenCloud; width: parent.width - root.panelLabelWidth; elide: Text.ElideRight } // 值：GPU 描述（过长省略）
                        }
                        Rectangle { x: root.panelPadding; width: parent.width - root.panelPadding * 2; height: 1; color: root.zenMist } // 分割线

                        // STORAGE
                        Text { x: root.panelPadding; text: "STORAGE"; font.pixelSize: root.fontSection; font.letterSpacing: 3; color: root.zenAsh } // 分区标题：存储
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2; spacing: root.panelGap * 3 // 一行：根分区占用
                            Text { text: "NVME"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth * 0.8 } // 标签：NVME/根分区
                            Rectangle {
                                width: root.sliderWidth * 0.8; height: 4; color: root.zenMist; anchors.verticalCenter: parent.verticalCenter // 进度条背景
                                Rectangle { width: parent.width * parseInt(root.nvmeUsage) / 100; height: 4; color: root.zenCloud } // 填充条：按百分比缩放
                            }
                            Text { text: root.nvmeUsage; font.pixelSize: root.fontSecondary; color: root.zenCloud } // 数值：如 42%
                        }
                        Rectangle { x: root.panelPadding; width: parent.width - root.panelPadding * 2; height: 1; color: root.zenMist } // 分割线

                        // PERFORMANCE
                        Text { x: root.panelPadding; text: "PERFORMANCE"; font.pixelSize: root.fontSection; font.letterSpacing: 3; color: root.zenAsh } // 分区标题：性能
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2 // 一行：load average
                            Text { text: "LOAD"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth * 0.8 } // 标签：load
                            Text { text: root.loadAvg; font.pixelSize: root.fontSecondary; color: root.zenCloud } // 值：1min load average
                        }
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2 // 一行：进程数量
                            Text { text: "PROCS"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth * 0.8 } // 标签：进程数
                            Text { text: root.processCount; font.pixelSize: root.fontSecondary; color: root.zenCloud } // 值：进程数量（粗略）
                        }
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2 // 一行：内存使用
                            Text { text: "MEM"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth * 0.8 } // 标签：内存
                            Text { text: root.memUsed.toFixed(1) + "G / " + root.memTotal.toFixed(0) + "G"; font.pixelSize: root.fontSecondary; color: root.zenCloud } // 值：已用/总量（GB）
                        }
                        Rectangle { x: root.panelPadding; width: parent.width - root.panelPadding * 2; height: 1; color: root.zenMist } // 分割线

                        // SYSTEM
                        Text { x: root.panelPadding; text: "SYSTEM"; font.pixelSize: root.fontSection; font.letterSpacing: 3; color: root.zenAsh } // 分区标题：系统
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2 // 一行：内核版本
                            Text { text: "KERNEL"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth * 0.8 } // 标签：内核
                            Text { text: root.kernelVer; font.pixelSize: root.fontSecondary; color: root.zenCloud } // 值：uname -r
                        }
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2 // 一行：CPU 型号
                            Text { text: "CPU"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth * 0.8 } // 标签：CPU
                            Text { text: root.cpuModel; font.pixelSize: root.fontSecondary; color: root.zenCloud; width: parent.width - root.panelLabelWidth; elide: Text.ElideRight } // 值：CPU 型号（过长省略）
                        }
                        Row {
                            x: root.panelPadding; width: parent.width - root.panelPadding * 2 // 一行：运行时间
                            Text { text: "UPTIME"; font.pixelSize: root.fontSecondary; color: root.zenSmoke; width: root.panelLabelWidth * 0.8 } // 标签：uptime
                            Text { text: root.uptime; font.pixelSize: root.fontSecondary; color: root.zenCloud } // 值：uptime -p（简化）
                        }
                        Item { width: 1; height: root.panelGap * 2 } // 底部留白
                    }
                }
            }
        }
    }
}
