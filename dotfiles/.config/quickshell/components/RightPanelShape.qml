import "../config" as Config
import QtQuick

// 右侧面板的颈部/主体连接轮廓。主体固定贴右，顶部只保留
// neckWidth 的平直连接段；flare 负责连续过渡到主体左上角。
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

    antialiasing: true
    // 两页共用固定外壳高度，Canvas 在开合和翻页期间都不 resize；
    // 线程化渲染只准备一次最终纹理，sizer 负责裁剪揭示。
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

        // bodyWidth 通常跟随 Canvas 宽度；调用方传入更小主体时仍贴紧
        // 右边缘，保证颈部与面板始终连成一体而不会向左漂移。
        const w = Math.max(0, root.width)
        const body = Math.max(0, Math.min(w, root.bodyWidth))
        const bodyLeft = w - body
        const h = Math.max(0, root.height)

        if (body <= 0 || h <= 0)
            return

        const neck = Math.max(0, Math.min(root.neckWidth, body))
        const neckLeft = Math.max(bodyLeft, w - neck)
        const f = Math.max(0, Math.min(
            root.flare,
            neck / 3,
            w / 2,
            h
        ))
        const r = Math.max(0, Math.min(
            root.radius,
            body / 2,
            Math.max(0, neckLeft - bodyLeft),
            Math.max(0, (h - f) / 2)
        ))

        ctx.beginPath()
        ctx.fillStyle = root.color

        // 主体顶边严格从 Bar 底边开始；右岛本身已经绘制颈部，面板不再
        // 重复填充该矩形区域，以免较高层的宿主窗口盖住右岛下半部内容。
        ctx.moveTo(bodyLeft + r, f)
        ctx.lineTo(w, f)

        // 主体右边与底部圆角。
        ctx.lineTo(w, Math.max(0, h - r))
        if (r > 0)
            ctx.arcTo(w, h, w - r, h, r)
        else
            ctx.lineTo(w, h)

        ctx.lineTo(bodyLeft + r, h)
        if (r > 0)
            ctx.arcTo(bodyLeft, h, bodyLeft, h - r, r)
        else
            ctx.lineTo(bodyLeft, h)

        // 主体左边与左上圆角。
        ctx.lineTo(bodyLeft, f + r)
        if (r > 0)
            ctx.arcTo(bodyLeft, f, bodyLeft + r, f, r)
        else
            ctx.lineTo(bodyLeft, f)

        ctx.closePath()
        ctx.fill()

        // 颈部左侧的 16×16 flare 伸入 Bar；边界右侧再保留同宽安全区，
        // 只盖住 Bar 关闭态遗留的左下外凸角。覆盖总宽仅 32px，不会
        // 触及颈部中的 Metrics、Tray 或 Power 内容。
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
