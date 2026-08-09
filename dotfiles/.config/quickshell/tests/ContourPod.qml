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
    // Optional top-edge wedge used by the unified right island.  The item
    // bounds include the wedge; the body itself is shifted right by this
    // amount so its content width remains stable when the wedge is added.
    property real leadingTriangleWidth: 0
    property real leadingTriangleHeight: 26
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
            const top = offsetY
            const triangleWidth = Math.max(0, root.leadingTriangleWidth)
            const bodyLeft = root.sideInset + triangleWidth
            const bodyRight = w - root.sideInset
            const triangleTip = root.sideInset
            const triangleHeight = Math.min(root.leadingTriangleHeight,
                                            Math.max(16, h * 0.42)) + offsetY
            // Keep the body compact while reserving a lower strip for the
            // offset silhouette, so the shadow is not clipped by Canvas.
            const bottom = h - root.shadowReserve - 2 + offsetY
            const lower = Math.max(top + 22, bottom - r)

            ctx.beginPath()
            if (triangleWidth > 0) {
                // The wedge is part of the same path as the body.  Its top
                // edge starts at the left tip and runs continuously into the
                // island; the return edge is the diagonal that meets the
                // body's left wall at triangleHeight.
                ctx.moveTo(triangleTip, top)
                ctx.lineTo(bodyRight - r, top)
            } else {
                ctx.moveTo(bodyLeft + r, top)
                ctx.lineTo(bodyRight - r, top)
            }
            ctx.bezierCurveTo(bodyRight - side, top,
                              bodyRight, top + 6,
                              bodyRight, top + 15)
            ctx.lineTo(bodyRight, lower)
            ctx.bezierCurveTo(bodyRight, bottom - 2,
                              bodyRight - r * 0.55, bottom,
                              bodyRight - r, bottom)
            ctx.lineTo(bodyLeft + r, bottom)
            ctx.bezierCurveTo(bodyLeft + r * 0.55, bottom,
                              bodyLeft, bottom - 2,
                              bodyLeft, lower)
            if (triangleWidth > 0) {
                ctx.lineTo(bodyLeft, triangleHeight)
                ctx.lineTo(triangleTip, top)
            } else {
                ctx.lineTo(bodyLeft, top + 15)
                ctx.bezierCurveTo(bodyLeft, top + 6,
                                  bodyLeft + side, top,
                                  bodyLeft + r, top)
            }
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
            const fill = ctx.createLinearGradient(0, 0, 0, root.height)
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
            const triangleWidth = Math.max(0, root.leadingTriangleWidth)
            const topStart = triangleWidth > 0
                            ? root.sideInset
                            : root.sideInset + root.shoulder
            ctx.moveTo(topStart, 0.7)
            ctx.lineTo(root.width - root.sideInset - root.shoulder, 0.7)
            ctx.strokeStyle = root.highlightColor
            ctx.globalAlpha = 0.58
            ctx.lineWidth = 1
            ctx.stroke()
            ctx.globalAlpha = 1
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root
            function onLeadingTriangleWidthChanged() { contourCanvas.requestPaint() }
            function onLeadingTriangleHeightChanged() { contourCanvas.requestPaint() }
            function onSideInsetChanged() { contourCanvas.requestPaint() }
            function onShoulderChanged() { contourCanvas.requestPaint() }
        }
    }

    Item {
        id: contentHost
        anchors.fill: parent
        anchors.leftMargin: root.sideInset + root.leadingTriangleWidth + 8
        anchors.rightMargin: root.sideInset + 8
        anchors.topMargin: root.topInset + 2
        anchors.bottomMargin: root.bottomInset + root.shadowReserve
    }
}
