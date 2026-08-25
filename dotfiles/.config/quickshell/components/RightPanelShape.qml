import "../config" as Config
import QtQuick

// 右侧面板的活动轮廓。主体按当前揭示宽高真实生长，左侧圆角始终
// 贴住活动边缘；颈部 flare 保持对齐 Bar，避免裁剪线切过固定圆角。
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

    clip: true

    // 原生场景图矩形随 sizer 同步变形，不需要逐帧重绘或重分配
    // 大尺寸 Canvas 纹理。右上角补成直角，以继续贴合屏幕右边缘。
    Rectangle {
        id: body

        x: root.bodyLeft
        y: root.effectiveFlare
        width: root.effectiveBodyWidth
        height: root.bodyHeight
        radius: root.effectiveRadius
        color: root.color
        antialiasing: true
        visible: width > 0 && height > 0
    }

    Rectangle {
        x: root.effectiveWidth - root.effectiveRadius
        y: root.effectiveFlare
        width: root.effectiveRadius
        height: Math.min(root.effectiveRadius, root.bodyHeight)
        color: root.color
        visible: width > 0 && height > 0
    }

    // flare 只占固定的 32×16px 左右，不参与主体宽高动画；即时绘制
    // 可避免窗口首次出现时线程化 Canvas 仍未提交纹理。
    Canvas {
        id: flareCap

        x: root.neckLeft - root.effectiveFlare
        width: root.effectiveFlare * 2
        height: root.effectiveFlare
        visible: root.effectiveFlare > 0
            && root.neckLeft > root.bodyLeft
        antialiasing: true
        renderStrategy: Canvas.Immediate

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()

            const f = height
            if (f <= 0)
                return

            ctx.beginPath()
            ctx.fillStyle = root.color
            ctx.moveTo(0, f)
            ctx.quadraticCurveTo(f, f, f, 0)
            ctx.lineTo(width, 0)
            ctx.lineTo(width, f)
            ctx.closePath()
            ctx.fill()
        }

        Connections {
            target: root

            function onColorChanged() {
                flareCap.requestPaint()
            }
        }
    }
}
