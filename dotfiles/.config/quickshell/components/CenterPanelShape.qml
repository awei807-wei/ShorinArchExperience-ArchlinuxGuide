import "../config" as Config
import QtQuick

// 中岛子面板的最终连体轮廓：顶部居中颈部接入 bar 中央岛，凹角喇叭
// 向外展开到主体，主体底部圆角。Canvas 始终按最终宽高绘制，动画只由
// 外层 viewport 揭示（与 RightPanelShape 同一架构）。
// 几何实现参考 Brainitech/Brain_Shell 的 PopupShape（MIT）。
Canvas {
    id: root

    property color color: Config.Theme.surface
    property real neckWidth: 330
    property real radius: Config.Theme.radiusMedium
    property real flare: Config.BarTuning.rightPanelFlare

    readonly property real w: Math.max(0, width)
    readonly property real h: Math.max(0, height)
    readonly property real effNeck: Math.max(0, Math.min(neckWidth, w))
    readonly property real neckLeft: (w - effNeck) / 2
    readonly property real neckRight: neckLeft + effNeck
    readonly property real effFlare: Math.max(0, Math.min(
        flare, effNeck / 3, w / 2, h))
    readonly property real bodyTop: effFlare
    readonly property real effRadius: Math.max(0, Math.min(
        radius, w / 2, Math.max(0, h - bodyTop) / 2))

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
        const r = root.effRadius
        const neckLeft = root.neckLeft
        const neckRight = root.neckRight

        if (w <= 0 || h <= 0)
            return

        ctx.beginPath()
        ctx.fillStyle = root.color

        // 主体：全宽，顶边位于 flare 下方，底部圆角
        ctx.moveTo(0, f)
        ctx.lineTo(w, f)
        ctx.lineTo(w, Math.max(f, h - r))
        if (r > 0)
            ctx.arcTo(w, h, w - r, h, r)
        else
            ctx.lineTo(w, h)
        ctx.lineTo(r, h)
        if (r > 0)
            ctx.arcTo(0, h, 0, h - r, r)
        else
            ctx.lineTo(0, h)
        ctx.lineTo(0, f)
        ctx.closePath()
        ctx.fill()

        // 颈部：居中窄条接入 bar，两侧凹角喇叭外展到主体宽度
        if (f > 0 && effNeck > 0) {
            ctx.beginPath()
            ctx.moveTo(neckLeft, 0)
            ctx.lineTo(neckRight, 0)
            ctx.quadraticCurveTo(neckRight, f, neckRight + f, f)
            ctx.lineTo(neckLeft - f, f)
            ctx.quadraticCurveTo(neckLeft, f, neckLeft, 0)
            ctx.closePath()
            ctx.fill()
        }
    }
}
