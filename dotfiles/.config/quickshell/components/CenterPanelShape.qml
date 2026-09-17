import "../config" as Config
import QtQuick

// 中岛子面板的连体轮廓：单条闭合路径依次经过
// 颈部左上 → 颈部右上 → 右侧内凹连接弧 → 主体右上圆角 → 右侧边
// → 右下圆角 → 底边 → 左下圆角 → 左侧边 → 左上圆角 → 左侧内凹连接弧 → 闭合。
// 三种半径严格区分：neckFlare（内凹连接弧）/ topRadius（主体上角）
// / bottomRadius（主体下角），空间不足时按约束收敛，不硬塞完整圆弧。
// 几何实现参考 Brainitech/Brain_Shell 的 PopupShape（MIT）。
Canvas {
    id: root

    property color color: Config.Theme.surface
    property real neckWidth: 300
    property real radius: Config.Theme.radiusMedium
    property real flare: Config.BarTuning.rightPanelFlare

    readonly property real w: Math.max(0, width)
    readonly property real h: Math.max(0, height)
    readonly property real effNeck: Math.max(0, Math.min(neckWidth, w))
    readonly property real shoulder: Math.max(0, (w - effNeck) / 2)
    // 内凹连接弧不能超过当前高度和左右肩部空间
    readonly property real effFlare: Math.max(0, Math.min(
        flare, h / 3, shoulder / 2))
    // 左右上角必须给连接弧留出横向空间
    readonly property real effTopRadius: Math.max(0, Math.min(
        radius, (h - effFlare) / 2, shoulder - effFlare))
    readonly property real effBottomRadius: Math.max(0, Math.min(
        radius, (h - effFlare) / 2, w / 2))
    readonly property real neckLeft: (w - effNeck) / 2
    readonly property real neckRight: neckLeft + effNeck

    antialiasing: true
    renderStrategy: Canvas.Threaded

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onColorChanged: requestPaint()
    onNeckWidthChanged: requestPaint()
    onRadiusChanged: requestPaint()
    onFlareChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)

        const w = root.w
        const h = root.h
        const f = root.effFlare
        const tr = root.effTopRadius
        const br = root.effBottomRadius
        const nl = root.neckLeft
        const nr = root.neckRight

        if (w <= 0 || h <= 0)
            return

        ctx.beginPath()
        ctx.fillStyle = root.color

        // 颈部顶边（贴住 bar 底边）
        ctx.moveTo(nl, 0)
        ctx.lineTo(nr, 0)
        // 右侧内凹连接弧：从颈部右上外展到主体顶边
        ctx.quadraticCurveTo(nr, f, nr + f, f)
        // 主体顶边右段 → 右上圆角 → 右侧边
        ctx.lineTo(w - tr, f)
        if (tr > 0)
            ctx.arcTo(w, f, w, f + tr, tr)
        // 右下圆角
        ctx.lineTo(w, h - br)
        if (br > 0)
            ctx.arcTo(w, h, w - br, h, br)
        // 底边 → 左下圆角 → 左侧边
        ctx.lineTo(br, h)
        if (br > 0)
            ctx.arcTo(0, h, 0, h - br, br)
        ctx.lineTo(0, f + tr)
        if (tr > 0)
            ctx.arcTo(0, f, tr, f, tr)
        // 主体顶边左段 → 左侧内凹连接弧回颈部左上
        ctx.lineTo(nl - f, f)
        ctx.quadraticCurveTo(nl, f, nl, 0)

        ctx.closePath()
        ctx.fill()
    }
}
