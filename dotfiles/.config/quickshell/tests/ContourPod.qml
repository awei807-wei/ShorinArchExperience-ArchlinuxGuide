import QtQuick

// 独立预览用的轮廓舱外壳。
// 顶部保持平直并嵌入 rail，底部以平滑肩部过渡到圆角；内容通过默认 data 属性注入。
Item {
    id: root

    default property alias contentData: contentHost.data

    property color surfaceTop: "#15181a"
    property color surfaceBottom: "#0b0e10"
    property color borderColor: "#67543b"
    property color highlightColor: "#ae7c39"
    property real shoulder: 24
    property real sideInset: 18
    property real topInset: 12
    property real bottomInset: 10
    property real shadowReserve: 10

    implicitHeight: 78

    Canvas {
        id: contourCanvas
        anchors.fill: parent
        antialiasing: true

        function drawContour(ctx, offsetY) {
            const w = root.width
            const h = root.height
            const r = Math.min(root.shoulder, Math.max(14, h * 0.28))
            const side = Math.min(9, Math.max(5, w * 0.012))
            const top = 7 + offsetY
            // Keep the body compact while reserving a lower strip for the
            // offset silhouette, so the shadow is not clipped by Canvas.
            const bottom = h - root.shadowReserve - 2 + offsetY
            const lower = Math.max(top + 22, bottom - r)

            ctx.beginPath()
            ctx.moveTo(root.sideInset + r, top)
            ctx.lineTo(w - root.sideInset - r, top)
            ctx.bezierCurveTo(w - root.sideInset - side, top,
                              w - root.sideInset, top + 6,
                              w - root.sideInset, top + 15)
            ctx.lineTo(w - root.sideInset, lower)
            ctx.bezierCurveTo(w - root.sideInset, bottom - 2,
                              w - root.sideInset - r * 0.55, bottom,
                              w - root.sideInset - r, bottom)
            ctx.lineTo(root.sideInset + r, bottom)
            ctx.bezierCurveTo(root.sideInset + r * 0.55, bottom,
                              root.sideInset, bottom - 2,
                              root.sideInset, lower)
            ctx.lineTo(root.sideInset, top + 15)
            ctx.bezierCurveTo(root.sideInset, top + 6,
                              root.sideInset + side, top,
                              root.sideInset + r, top)
            ctx.closePath()
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()

            // A broad, low-contrast silhouette keeps the pod attached to the screen
            // without requiring an external graphical-effects import.
            drawContour(ctx, 6)
            ctx.fillStyle = "#0000007d"
            ctx.fill()

            drawContour(ctx, 0)
            const fill = ctx.createLinearGradient(0, 7, 0, root.height)
            fill.addColorStop(0, root.surfaceTop)
            fill.addColorStop(0.44, "#111416")
            fill.addColorStop(1, root.surfaceBottom)
            ctx.fillStyle = fill
            ctx.fill()

            ctx.strokeStyle = root.borderColor
            ctx.lineWidth = 1
            ctx.stroke()

            // A short warm edge catches the light along the otherwise flat top.
            ctx.beginPath()
            ctx.moveTo(root.sideInset + root.shoulder, 7.7)
            ctx.lineTo(root.width - root.sideInset - root.shoulder, 7.7)
            ctx.strokeStyle = root.highlightColor
            ctx.globalAlpha = 0.58
            ctx.lineWidth = 1
            ctx.stroke()
            ctx.globalAlpha = 1
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Item {
        id: contentHost
        anchors.fill: parent
        anchors.leftMargin: root.sideInset + 8
        anchors.rightMargin: root.sideInset + 8
        anchors.topMargin: root.topInset + 2
        anchors.bottomMargin: root.bottomInset + root.shadowReserve
    }
}
