import "../config" as Config
import QtQuick

// 右侧面板的颈部/主体连接轮廓。页面切换只改变主体中段高度和
// 底部圆角位置；顶部连接与两个 Canvas 的纹理尺寸始终保持稳定。
// 几何实现参考 Brainitech/Brain_Shell 的 PopupShape（MIT）。
Item {
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
        height
    ))
    readonly property real effectiveRadius: Math.max(0, Math.min(
        radius,
        effectiveBodyWidth / 2,
        Math.max(0, neckLeft - bodyLeft),
        Math.max(0, (height - effectiveFlare) / 2)
    ))

    // 这些几何属性同时作为动画门禁的观测点：跨页时顶部和两个
    // Canvas 的高度不变，只有同步 Rectangle 与底部 Canvas 的位置变化。
    readonly property real topSectionHeight:
        effectiveFlare + effectiveRadius
    readonly property real bottomSectionHeight: effectiveRadius
    readonly property real topCanvasY: topCap.y
    readonly property real topCanvasHeight: topCap.height
    readonly property real bottomCanvasY: bottomCap.y
    readonly property real bottomCanvasHeight: bottomCap.height
    readonly property real bodySectionTop: bodyFill.y
    readonly property real bodySectionBottom:
        bodyFill.y + bodyFill.height

    clip: true

    // 主体中段使用场景图原生矩形同步伸缩，不依赖线程化 Canvas
    // 的异步纹理重建；它与上下两段首尾相接，因此动画期间不会透底。
    Rectangle {
        id: bodyFill

        x: root.bodyLeft
        y: root.topSectionHeight
        width: root.effectiveBodyWidth
        height: Math.max(0, root.height
            - root.effectiveFlare
            - 2 * root.effectiveRadius)
        color: root.color
    }

    // 顶部连接、左上圆角与 flare 的纹理尺寸不再绑定页面高度。
    Canvas {
        id: topCap

        anchors.top: parent.top
        anchors.right: parent.right
        width: root.effectiveWidth
        height: root.topSectionHeight
        antialiasing: true
        renderStrategy: Canvas.Threaded

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()

            const w = root.effectiveWidth
            const body = root.effectiveBodyWidth
            const bodyLeft = root.bodyLeft
            const neckLeft = root.neckLeft
            const f = root.effectiveFlare
            const r = root.effectiveRadius

            if (body <= 0 || height <= 0)
                return

            ctx.beginPath()
            ctx.fillStyle = root.color
            ctx.moveTo(bodyLeft + r, f)
            ctx.lineTo(w, f)
            ctx.lineTo(w, height)
            ctx.lineTo(bodyLeft, height)
            ctx.lineTo(bodyLeft, f + r)
            if (r > 0)
                ctx.arcTo(bodyLeft, f, bodyLeft + r, f, r)
            else
                ctx.lineTo(bodyLeft, f)
            ctx.closePath()
            ctx.fill()

            // 颈部左侧形成连接弧，右侧只抹平旧外凸角；覆盖宽度仍
            // 限制在边界左右各一个 flare，避免遮挡右岛内容。
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

    // 底部 Canvas 固定为一个圆角高，只移动位置而不调整纹理尺寸。
    Canvas {
        id: bottomCap

        anchors.right: parent.right
        y: Math.max(root.topSectionHeight,
                    root.height - height)
        width: root.effectiveWidth
        height: root.bottomSectionHeight
        visible: height > 0
        antialiasing: true
        renderStrategy: Canvas.Threaded

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()

            const w = root.effectiveWidth
            const body = root.effectiveBodyWidth
            const bodyLeft = root.bodyLeft
            const r = root.effectiveRadius

            if (body <= 0 || r <= 0)
                return

            ctx.beginPath()
            ctx.fillStyle = root.color
            ctx.moveTo(bodyLeft, 0)
            ctx.lineTo(w, 0)
            ctx.arcTo(w, r, w - r, r, r)
            ctx.lineTo(bodyLeft + r, r)
            ctx.arcTo(bodyLeft, r, bodyLeft, 0, r)
            ctx.closePath()
            ctx.fill()
        }
    }

    Connections {
        target: root

        function repaintCaps() {
            topCap.requestPaint()
            bottomCap.requestPaint()
        }

        function onColorChanged() { repaintCaps() }
        function onNeckWidthChanged() { repaintCaps() }
        function onBodyWidthChanged() { repaintCaps() }
        function onRadiusChanged() { repaintCaps() }
        function onFlareChanged() { repaintCaps() }
    }
}
