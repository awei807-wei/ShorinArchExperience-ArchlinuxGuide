import QtQuick
import "../"

// SpectrumVisualizer — VCPChat Musicmodules/music-visualizer.js 三层渲染 1:1 移植。
// 绘制顺序与原版 rAF 帧一致：人声正弦波 → 渐变填充曲线 → 粒子弹簧线。
// 数据来自 CavaService.easedSpectrum（64 × 0..1，已含 0.18 前端缓动，
// 即 VCPChat 的 currentVisualizerData 同层），这里只负责渲染。
// 颜色默认跟随 Brain Theme（→ Config.Theme，matugen 动态配色热更新）。

//
// 原版参数（music-visualizer.js / music.js:167-175）：
//   Particle  spring 0.08 / friction 0.85 / 初值 y = h-10
//   曲线      y = h - v*h*1.2，Catmull-Rom→bezier tension 0.5，
//             填充渐变 alpha 0.85→0.6 处 0.4→1 处 0.05
//   人声      4 层正弦（alpha .1/.2/.4/.6，amp 5/8/12/15 + vocal*35，
//             edgeFade = sin²(x/w·π)），vocal 缓动 0.15，频段 300–3400Hz
//   粒子线    rgba(tint,0.85) 1.5px round join/cap
// 本地适配：原版画布 80px / 50px，条带可用高度按 ampScale = h/50 等比缩放；
// 人声频段按对数 bin 换算（fmin 20Hz，fmax 24kHz，bin 64）。
Canvas {
    id: root

    // 64 × 0..1 频谱帧（CavaService.easedSpectrum）
    property var spectrum: []
    // 驱动动画（面板可见即跑，与 VCPChat rAF 常驻一致）
    property bool running: false
    // 线条/填充颜色：默认跟随 matugen 动态强调色（Theme.active → Config.Theme.accent）
    property color tint: Theme.active

    // ── 原版常量 ──────────────────────────────────────────────────────────────
    readonly property int _particleCount: 45
    readonly property real _tension: 0.5
    readonly property real _curveGain: 1.2        // 纵向增益（高峰出画布）
    readonly property real _particleLift: 6       // 粒子目标点在曲线上方 6px
    readonly property real _vocalSmooth: 0.15     // 人声能量缓动
    readonly property int _vocalFminHz: 300       // 人声频段
    readonly property int _vocalFmaxHz: 3400
    readonly property real _binFminHz: 20         // worker 对数分箱范围
    readonly property real _binFmaxHz: 24000
    readonly property real _ampScale: height / 50 // 原版人声画布 50px 等比缩放

    readonly property var _vocalWaves: [
        { alpha: 0.1, speed: 0.05, frequency: 0.015, amplitude: 5, phase: 0 },
        { alpha: 0.2, speed: 0.08, frequency: 0.02, amplitude: 8, phase: 2 },
        { alpha: 0.4, speed: 0.12, frequency: 0.025, amplitude: 12, phase: 4 },
        { alpha: 0.6, speed: 0.15, frequency: 0.03, amplitude: 15, phase: 6 }
    ]

    // 300–3400Hz 在对数 64 bin 中的区间（原版按 21.5Hz/bin 线性折算）
    readonly property int _vocalStartBin: {
        var r = Math.log(_vocalFminHz / _binFminHz) / Math.log(_binFmaxHz / _binFminHz)
        return Math.max(0, Math.floor(r * (spectrum.length - 1)))
    }
    readonly property int _vocalEndBin: {
        var r = Math.log(_vocalFmaxHz / _binFminHz) / Math.log(_binFmaxHz / _binFminHz)
        return Math.min(spectrum.length, Math.max(_vocalStartBin + 1,
            Math.floor(r * (spectrum.length - 1))))
    }

    // ── 运行时状态（与原版 app.* 同名量对应） ──────────────────────────────────
    property var _particles: []
    property real _smoothedVocalEnergy: 0
    property var _rgb: ({ r: Math.round(tint.r * 255),
                          g: Math.round(tint.g * 255),
                          b: Math.round(tint.b * 255) })
    onTintChanged: _rgb = ({ r: Math.round(tint.r * 255),
                             g: Math.round(tint.g * 255),
                             b: Math.round(tint.b * 255) })

    antialiasing: true
    renderStrategy: Canvas.Immediate
    onPaint: _draw()

    onWidthChanged: _recreateParticles()
    Component.onCompleted: _recreateParticles()

    // 16ms ≈ 60fps（对齐 VCPChat 前端 rAF 节奏）
    Timer {
        interval: 16
        running: root.running && root.visible && root.width > 0 && root.height > 0
        repeat: true
        onTriggered: root.requestPaint()
    }

    function _recreateParticles() {
        // 原版 recreateParticles：均匀铺 x，初始贴底 h-10
        const ps = []
        for (let i = 0; i < _particleCount; i++) {
            ps.push({
                x: width * (i / (_particleCount - 1)),
                y: height - 10,
                targetY: height - 10,
                vy: 0
            })
        }
        _particles = ps
    }

    // 帧驱动：粒子弹簧物理 + 人声缓动 + 三层绘制（顺序同原版 draw()）
    function _draw() {
        const ctx = getContext("2d")
        const w = width, h = height
        const data = root.spectrum
        ctx.clearRect(0, 0, w, h)
        if (!data || data.length === 0)
            return

        // ── 人声波形（原版 drawVocalVisualizer） ─────────────────────────────
        let vocalEnergy = 0
        const sBin = _vocalStartBin
        const eBin = Math.min(_vocalEndBin, data.length)
        for (let i = sBin; i < eBin; i++)
            vocalEnergy += data[i]
        vocalEnergy = (vocalEnergy / (eBin - sBin)) || 0
        _smoothedVocalEnergy += (vocalEnergy - _smoothedVocalEnergy) * _vocalSmooth

        const centerY = h / 2
        const time = Date.now()
        const rgb = _rgb
        for (let wi = 0; wi < _vocalWaves.length; wi++) {
            const wave = _vocalWaves[wi]
            ctx.beginPath()
            ctx.strokeStyle = "rgba(" + rgb.r + "," + rgb.g + "," + rgb.b + ","
                + wave.alpha + ")"
            ctx.lineWidth = 1.5
            for (let x = 0; x <= w; x += 2) {
                const edgeFade = Math.pow(Math.sin((x / w) * Math.PI), 2)
                const y = centerY
                    + Math.sin(x * wave.frequency + time * wave.speed * 0.01
                        + wave.phase)
                        * (wave.amplitude + _smoothedVocalEnergy * 35) * _ampScale
                        * edgeFade
                if (x === 0)
                    ctx.moveTo(x, y)
                else
                    ctx.lineTo(x, y)
            }
            ctx.stroke()
        }

        // ── 渐变填充曲线（原版 drawVisualizer） ─────────────────────────────
        const bufferLength = data.length
        const gradient = ctx.createLinearGradient(0, 0, 0, h)
        gradient.addColorStop(0, "rgba(" + rgb.r + "," + rgb.g + "," + rgb.b + ",0.85)")
        gradient.addColorStop(0.6, "rgba(" + rgb.r + "," + rgb.g + "," + rgb.b + ",0.4)")
        gradient.addColorStop(1, "rgba(" + rgb.r + "," + rgb.g + "," + rgb.b + ",0.05)")
        ctx.fillStyle = gradient
        ctx.lineWidth = 2

        const sliceWidth = w / (bufferLength - 1)
        const getPoint = function(index) {
            const value = data[index] || 0
            return [index * sliceWidth, h - (value * h * _curveGain)]
        }

        ctx.beginPath()
        ctx.moveTo(0, h)
        for (let i = 0; i < bufferLength - 1; i++) {
            const p1 = getPoint(i)
            const p2 = getPoint(i + 1)
            const prev = i > 0 ? getPoint(i - 1) : p1
            const next = i < bufferLength - 2 ? getPoint(i + 2) : p2
            const cp1x = p1[0] + (p2[0] - prev[0]) / 6 * _tension
            const cp1y = p1[1] + (p2[1] - prev[1]) / 6 * _tension
            const cp2x = p2[0] - (next[0] - p1[0]) / 6 * _tension
            const cp2y = p2[1] - (next[1] - p1[1]) / 6 * _tension
            if (i === 0)
                ctx.lineTo(p1[0], p1[1])
            ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, p2[0], p2[1])
        }
        ctx.lineTo(w, h)
        ctx.closePath()
        ctx.fill()

        // ── 粒子弹簧线（原版 L350-390） ──────────────────────────────────────
        const ps = _particles
        for (let pi = 0; pi < ps.length; pi++) {
            const p = ps[pi]
            const ratio = p.x / w
            const idxFloat = ratio * (bufferLength - 1)
            const i1 = Math.floor(idxFloat)
            const i2 = Math.min(i1 + 1, bufferLength - 1)
            const v1 = data[i1] || 0
            const v2 = data[i2] || 0
            const value = v1 + (v2 - v1) * (idxFloat - i1)
            p.targetY = h - (value * h * _curveGain) - _particleLift
            // 弹簧物理：ay = dy*0.08; vy = (vy+ay)*0.85; y += vy
            const dy = p.targetY - p.y
            p.vy = (p.vy + dy * 0.08) * 0.85
            p.y += p.vy
        }

        if (ps.length > 1) {
            ctx.beginPath()
            ctx.moveTo(ps[0].x, ps[0].y)
            for (let qi = 0; qi < ps.length - 2; qi++) {
                const q1 = ps[qi]
                const q2 = ps[qi + 1]
                const xc = (q1.x + q2.x) / 2
                const yc = (q1.y + q2.y) / 2
                ctx.quadraticCurveTo(q1.x, q1.y, xc, yc)
            }
            const secondLast = ps[ps.length - 2]
            const last = ps[ps.length - 1]
            ctx.quadraticCurveTo(secondLast.x, secondLast.y, last.x, last.y)
            ctx.strokeStyle = "rgba(" + rgb.r + "," + rgb.g + "," + rgb.b + ",0.85)"
            ctx.lineWidth = 1.5
            ctx.lineJoin = "round"
            ctx.lineCap = "round"
            ctx.stroke()
        }
    }
}
