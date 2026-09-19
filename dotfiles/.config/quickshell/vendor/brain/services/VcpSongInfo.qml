pragma Singleton

// VcpSongInfo — VCPChat 播放源数据增强（MPRIS 盲区补全）。
//
// 背景：VCPChat（Electron/Chromium）经 MPRIS 暴露了真实标题/艺术家/进度，
// 但 mpris:length 恒为 60s（前端用 60s 静音 WAV 当 gapless 幻影播放源，
// 见 Musicmodules/music-ui.js createSilentAudio），且从不广播 mpris:artUrl
// （Chromium 不把 MediaSession artwork 带进 MPRIS 元数据）。
//
// 补全链路（全部由换曲事件触发，无轮询）：
//   1) 曲库匹配：读 <VCPChat>/AppData/songlist.json（FileView 常驻 + inotify
//      失效重读），按 MPRIS 标题/艺术家 回查 → 命中即得 albumArt 封面路径
//      （封面在扫描期已导出为独立缓存文件，无需运行时解析音频标签）
//   2) ffprobe 兜底：对命中的音频路径读文件头拿真实时长 —— 每个路径整个
//      会话至多探测一次，结果缓存在 _durationCache
//
// IO 成本：songlist.json 约 30KB、FileView 异步读；ffprobe 每首歌一次
// （只读文件头，毫秒级）。相对 CavaService 的 pw-record 采集链路可忽略。
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ── 对外结果（PlayerCard 消费） ─────────────────────────────────────────
    readonly property bool   matched: root._matchedPath !== ""   // 本次曲目命中曲库
    readonly property string artPath: root._artPath              // 本地封面绝对路径（"" = 无）
    readonly property real   length: root._length                // 真实时长（秒，0 = 未知）

    // 引擎实时播放态（enginePolling 由 PlayerCard 在"命中 + 播放中"时置位）。
    // Chromium 的 MPRIS Position 同样来自 60s 幻影源（循环回绕），进度必须
    // 以 rust 引擎 /state 的 current_time/duration 为准。
    property bool enginePolling: false
    readonly property bool   engineAlive: root._engineAlive       // 最近一次 /state 可达
    readonly property real   enginePos: root._enginePos           // 当前播放位置（秒）
    readonly property real   engineDur: root._engineDur           // 引擎报告时长（秒）

    function _pollNow() {
        var req = new XMLHttpRequest()
        req.open("GET", root._engineUrl + "/state")
        req.onreadystatechange = function() {
            if (req.readyState !== XMLHttpRequest.DONE) return
            if (req.status !== 200) {
                root._engineAlive = false          // 引擎未运行/端口不对
                return
            }
            try {
                const st = JSON.parse(req.responseText).state
                if (!st) return
                root._engineAlive = true
                root._engineDur = st.duration ?? 0
                root._enginePos = st.current_time ?? 0
                if ((st.duration ?? 0) > 0) root._length = st.duration
                // 引擎 file_path 是权威身份：直接按路径精确回查曲库拿封面，
                // 并缓存时长（后续同曲不再依赖轮询）
                const fp = st.file_path ?? ""
                if (fp !== "" && fp !== root._matchedPath) {
                    const e = root._findByPath(fp)
                    if (e) {
                        root._matchedPath = e.path || ""
                        if (e.albumArt) root._artPath = e.albumArt
                        if ((st.duration ?? 0) > 0)
                            root._durationCache[e.path] = st.duration
                    }
                }
            } catch (e) { /* JSON 半截：下轮重试 */ }
        }
        req.send()
    }

    property Timer _pollTimer: Timer {
        interval: 1000
        repeat: true
        running: root.enginePolling
        onTriggered: root._pollNow()
    }

    function _findByPath(p) {
        for (var i = 0; i < root._tracks.length; ++i)
            if (root._tracks[i].path === p) return root._tracks[i]
        return null
    }

    readonly property string _engineUrl: "http://127.0.0.1:63789"   // musicHandlers.js AUDIO_ENGINE_URL
    property bool _engineAlive: false
    property real _enginePos: 0
    property real _engineDur: 0

    // ── 输入：PlayerCard 注入当前 MPRIS 曲目（换曲时调用） ───────────────────
    // force=true 跳过同曲去抖（曲库解析完成后回补用——此时曲目没变，
    // 但第一次 lookup 时曲库为空，必须重跑匹配）。
    function lookup(title, artist, force) {
        const t = (title ?? "").toString().trim()
        const a = (artist ?? "").toString().trim()
        if (!force && t === root._lastTitle && a === root._lastArtist) return  // 同曲去抖
        root._lastTitle = t
        root._lastArtist = a
        root._seq++

        // 曲库未就绪（首次冷启动/文件曾被读半截）：允许 30s 一次的温和重试
        if (root._tracks.length === 0 && Date.now() - root._libRetryAt > 30000) {
            root._libRetryAt = Date.now()
            root._lib.reload()
        }

        const entry = root._findTrack(t, a)
        if (!entry) {
            root._matchedPath = ""
            root._artPath = ""
            root._length = 0
            root._wantPath = ""
            return
        }

        root._matchedPath = entry.path || ""
        root._artPath = entry.albumArt || ""
        const cached = root._durationCache[entry.path]
        if (cached !== undefined) {
            root._length = cached
            root._wantPath = ""
        } else {
            root._length = 0
            root._wantPath = entry.path || ""
            root._maybeProbe()
        }
    }

    // ── VCPChat 安装根 ──────────────────────────────────────────────────────
    // 可用环境变量 VCPCHAT_ROOT 覆盖（比如装到别处/多份并存时，在
    // shell 的启动环境里 export 即可）；默认跟随当前安装位置
    // $HOME/Downloads/VCPChat。曲库文件由 FileView watchChanges 监听，
    // 路径失效时 onLoadFailed 静默、不影响其他播放器。
    // 注意：Quickshell.env 未设置时返回 null（不是 ""），直接用 ?? 兜底；
    // 之前用 `if (env !== "")` 判断，null 落进默认分支导致路径变成
    // "/AppData/songlist.json"（读不到曲库 → 封面/时长全部失效）。
    readonly property string _appRoot: {
        const env = Quickshell.env("VCPCHAT_ROOT")
        if (env !== null && env !== undefined && env !== "") return env
        const home = Quickshell.env("HOME") ?? "/home/shiyi"
        return home + "/Downloads/VCPChat"
    }

    readonly property string _libPath: root._appRoot + "/AppData/songlist.json"

    property FileView _lib: FileView {
        path: root._libPath
        watchChanges: true   // VCPChat 增删曲目/重扫封面时自动重读
        onLoaded: root._parseLib()
        onLoadFailed: { /* 文件暂不可读：保持旧数据，等 lookup 的节流重试 */ }
    }

    // FileView 不自动加载（仅设置 path 不触发读取），必须显式 reload。
    // 复现坑：漏掉这行 → 曲库永远为空 → matched 恒 false。
    Component.onCompleted: root._lib.reload()

    property var _tracks: []
    property real _libRetryAt: 0

    property Timer _parseRetry: Timer {
        interval: 400
        repeat: false
        onTriggered: root._parseLib()
    }

    function _parseLib() {
        try {
            const arr = JSON.parse(_lib.text())
            root._tracks = Array.isArray(arr) ? arr : []
            root._libReady = true
            // 曲库晚于 lookup 到达是常态（FileView 异步 + VCPChat 播放先启动）：
            // 解析完成后用"最后请求的曲子"补一次匹配，消除启动竞态。
            // force=true：曲子没变，但第一次 lookup 时曲库为空，必须重跑。
            if (root._lastTitle !== "" && root._lastTitle !== "Nothing Playing")
                root.lookup(root._lastTitle, root._lastArtist, true)
        } catch (e) {
            // 撞上写入半截（writeJson 非原子）：400ms 后重读一次
            root._parseRetry.restart()
        }
    }

    property bool _libReady: false

    // ── 匹配策略：标题精确（忽略大小写）；标题命中多条时按艺术家精确/互相包含择优 ──
    function _findTrack(title, artist) {
        if (!title) return null
        const tl = title.toLowerCase()
        const al = artist.toLowerCase()
        var first = null
        for (var i = 0; i < root._tracks.length; ++i) {
            const e = root._tracks[i]
            if ((e.title || "").toLowerCase() !== tl) continue
            if (!first) first = e
            const ea = (e.artist || "").toLowerCase()
            if (ea === al
                    || (ea && al && (ea.indexOf(al) !== -1 || al.indexOf(ea) !== -1)))
                return e   // 标题 + 艺术家都中：最优
        }
        return first       // 仅标题命中：可接受（封面/时长本就按曲绑定）
    }

    // ── ffprobe 兜底（真实时长） ─────────────────────────────────────────────
    property string _wantPath: ""      // 期望探测的音频路径
    property string _probingPath: ""   // 正在探测（非空 = 忙）
    property var _durationCache: ({})  // path → 秒（失败记 0，避免反复重试）
    property int _seq: 0               // lookup 代数：作废旧探测结果
    property int _probeSeq: 0

    property Process _probeProc: Process {
        id: probeProc
        command: []
        stdout: StdioCollector {
            id: probeOut
            onStreamFinished: root._onProbeFinished(probeOut.text)
        }
        stderr: StdioCollector {}
    }

    function _maybeProbe() {
        if (root._probingPath !== "") return                       // 忙：串行排队
        if (root._wantPath === "") return
        if (root._durationCache[root._wantPath] !== undefined) return
        root._probeSeq = root._seq
        root._probingPath = root._wantPath
        _probeProc.command = [
            "ffprobe", "-v", "quiet",
            "-print_format", "json", "-show_format",
            root._probingPath
        ]
        _probeProc.running = true
    }

    function _onProbeFinished(out) {
        var dur = 0
        try {
            const fmt = JSON.parse(out).format
            dur = Number(fmt && fmt.duration) || 0
        } catch (e) { dur = 0 }
        root._durationCache[root._probingPath] = dur
        if (root._probeSeq === root._seq)   // 只把"当前曲"的结果写回对外状态
            root._length = dur
        root._probingPath = ""
        root._maybeProbe()                  // 若换曲排了队，接着处理
    }

    // ── 内部状态 ────────────────────────────────────────────────────────────
    property string _lastTitle: ""
    property string _lastArtist: ""
    property string _matchedPath: ""
    property string _artPath: ""
    property real _length: 0
}
