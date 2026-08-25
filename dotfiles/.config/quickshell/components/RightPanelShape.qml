import "../config" as Config
import QtQuick

// 右侧面板的最终连体轮廓。Canvas 始终保持最终宽高，动画只由外层
// viewport 揭示，因此路径不会经历凹角与圆角无法成立的中间拓扑。
// 几何实现参考 Brainitech/Brain_Shell 的 PopupShape（MIT）。
Canvas {
    id: root

    property color color: Config.Theme.surface
    property alias surfaceColor: root.color

    property real neckWidth: Config.BarTuning.rightPanelNeckWidth
    property real bodyWidth: width
    property real radius: Config.BarTuning.rightPanelRadius
    property alias cornerRadius: root.radius
    property real flare: Config.BarTuning.rightPanelFlare
    property alias flareWidth: root.flare
    property alias flareHeight: root.flare

    readonly property real effectiveWidth: Math.max(0, width)
    readonly property real effectiveHeight: Math.max(0, height)
    readonly property real effectiveBodyWidth: Math.max(
        0, Math.min(effectiveWidth, bodyWidth)
    )
    readonly property real bodyLeft:
        effectiveWidth - effectiveBodyWidth
    readonly property real effectiveNeckWidth: Math.max(
        0, Math.min(neckWidth, effectiveBodyWidth)
    )
    readonly property real neckLeft: Math.max(
        bodyLeft, effectiveWidth - effectiveNeckWidth
    )
    readonly property real effectiveFlare: Math.max(0, Math.min(
        flare,
        effectiveNeckWidth / 3,
        effectiveWidth / 2,
        effectiveHeight
    ))
    readonly property real bodyHeight: Math.max(
        0, effectiveHeight - effectiveFlare
    )
    readonly property real effectiveRadius: Math.max(0, Math.min(
        radius,
        effectiveBodyWidth / 2,
        Math.max(0, neckLeft - bodyLeft),
        bodyHeight / 2
    ))

    antialiasing: true
    renderStrategy: Canvas.Threaded

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onColorChanged: requestPaint()
    onNeckWidthChanged: requestPaint()
    onBodyWidthChanged: requestPaint()
    onRadiusChanged: requestPaint()
    onFlareChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)

        const w = root.effectiveWidth
        const h = root.effectiveHeight
        const body = root.effectiveBodyWidth
        const bodyLeft = root.bodyLeft
        const neckLeft = root.neckLeft
        const f = root.effectiveFlare
        const r = root.effectiveRadius

        if (body <= 0 || h <= 0)
            return

        ctx.beginPath()
        ctx.fillStyle = root.color

        // 主体顶边位于 flare 下方；右边贴屏，因此右上角保持直角。
        ctx.moveTo(bodyLeft + r, f)
        ctx.lineTo(w, f)
        ctx.lineTo(w, Math.max(f, h - r))

        if (r > 0)
            ctx.arcTo(w, h, w - r, h, r)
        else
            ctx.lineTo(w, h)

        ctx.lineTo(bodyLeft + r, h)
        if (r > 0)
            ctx.arcTo(bodyLeft, h, bodyLeft, h - r, r)
        else
            ctx.lineTo(bodyLeft, h)

        ctx.lineTo(bodyLeft, f + r)
        if (r > 0)
            ctx.arcTo(bodyLeft, f, bodyLeft + r, f, r)
        else
            ctx.lineTo(bodyLeft, f)

        ctx.closePath()
        ctx.fill()

        // 颈部左侧以 flare 接入 Bar；右侧只覆盖一个 flare 的安全区，
        // 不遮挡右岛中的 Metrics、Tray 与 Power 内容。
        if (f > 0 && neckLeft > bodyLeft) {
            const flareLeft = Math.max(bodyLeft, neckLeft - f)
            const coverRight = Math.min(w, neckLeft + f)

            ctx.beginPath()
            ctx.moveTo(flareLeft, f)
            ctx.quadraticCurveTo(neckLeft, f, neckLeft, 0)
            ctx.lineTo(coverRight, 0)
            ctx.lineTo(coverRight, f)
            ctx.closePath()
            ctx.fill()
        }
    }
}
