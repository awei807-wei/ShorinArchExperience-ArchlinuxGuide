import QtQuick

// 与顶部 rail 连成一体的下伸轮廓。
// railHeight 以上的区域始终铺满整个 item；从 rail 底部开始，左右边缘
// 通过四分之一圆弧内切到主体，透明间隙因此只出现在 rail 下方。
Item {
    id: root

    default property alias contentData: contentHost.data

    property color surfaceTop: "#101314"
    property color surfaceBottom: "#0b0e10"
    property color borderColor: "#67543b"
    property color highlightColor: "#ae7c39"
    property real sideInset: 18
    // Horizontal width of the rail-to-body quarter ellipse. Its vertical
    // height is always derived from railHeight to the visible island bottom.
    property real joinWidth: 20
    property bool flushLeft: false
    property bool flushRight: false
    property real railHeight: 9
    property real topInset: 12
    property real bottomInset: 10
    property real shadowReserve: 5

    implicitHeight: 78

    readonly property real leftJoinWidth: root.flushLeft ? 0 : root.joinWidth
    readonly property real rightJoinWidth: root.flushRight ? 0 : root.joinWidth

    Canvas {
        id: contourCanvas
        anchors.fill: parent
        antialiasing: true

        function drawContour(ctx, offsetY) {
            const w = root.width
            const h = root.height
            const leftJoinWidth = Math.max(0, root.leftJoinWidth)
            const rightJoinWidth = Math.max(0, root.rightJoinWidth)
            const top = Math.max(0, offsetY)
            const railBottom = root.railHeight + offsetY
            const bottom = h - root.shadowReserve - 2 + offsetY
            const curveHeight = Math.max(1, bottom - railBottom)
            const kappa = 0.55228475
            const leftBody = leftJoinWidth
            const rightBody = w - rightJoinWidth

            ctx.beginPath()
            // The top edge belongs to the rail and is deliberately not
            // highlighted or outlined separately.
            ctx.moveTo(0, top)
            ctx.lineTo(w, top)
            ctx.lineTo(w, railBottom)

            if (rightJoinWidth > 0) {
                // Full-height quarter ellipse: the curve runs directly from
                // the rail bottom to the body's flat bottom, with no vertical
                // segment after it.
                ctx.bezierCurveTo(w,
                                  railBottom + curveHeight * kappa,
                                  rightBody + rightJoinWidth * kappa,
                                  bottom,
                                  rightBody,
                                  bottom)
            } else {
                // A flush edge is allowed to remain vertically clipped.
                ctx.lineTo(w, bottom)
            }

            ctx.lineTo(leftBody, bottom)
            if (leftJoinWidth > 0) {
                // Mirror of the right full-height quarter ellipse.
                ctx.bezierCurveTo(leftBody - leftJoinWidth * kappa,
                                  bottom,
                                  0,
                                  railBottom + curveHeight * kappa,
                                  0,
                                  railBottom)
            } else {
                ctx.lineTo(0, railBottom)
            }

            ctx.lineTo(0, top)
            ctx.closePath()
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()

            // Keep the silhouette shadow subtle; it must not read as a second
            // floating capsule underneath the rail-attached body.
            drawContour(ctx, 4)
            ctx.fillStyle = "#00000038"
            ctx.fill()

            drawContour(ctx, 0)
            const fill = ctx.createLinearGradient(0, 0, 0, root.height)
            fill.addColorStop(0, root.surfaceTop)
            fill.addColorStop(0.5, "#0f1214")
            fill.addColorStop(1, root.surfaceBottom)
            ctx.fillStyle = fill
            ctx.fill()

            // Only a very low-contrast lower/side edge is retained.  There is
            // intentionally no top stroke or highlight: the rail is one surface.
            ctx.beginPath()
            const leftJoinWidth = Math.max(0, root.leftJoinWidth)
            const rightJoinWidth = Math.max(0, root.rightJoinWidth)
            const leftBody = leftJoinWidth
            const rightBody = root.width - rightJoinWidth
            const bottom = root.height - root.shadowReserve - 2
            const railBottom = root.railHeight
            const curveHeight = Math.max(1, bottom - railBottom)
            const kappa = 0.55228475
            ctx.moveTo(leftBody, bottom)
            if (leftJoinWidth > 0) {
                ctx.bezierCurveTo(leftBody - leftJoinWidth * kappa,
                                  bottom,
                                  0,
                                  railBottom + curveHeight * kappa,
                                  0,
                                  railBottom)
            } else {
                ctx.lineTo(0, railBottom)
            }
            ctx.moveTo(rightBody, bottom)
            if (rightJoinWidth > 0) {
                ctx.bezierCurveTo(rightBody + rightJoinWidth * kappa,
                                  bottom,
                                  root.width,
                                  railBottom + curveHeight * kappa,
                                  root.width,
                                  railBottom)
            } else {
                ctx.lineTo(root.width, railBottom)
            }
            ctx.moveTo(leftBody, bottom)
            ctx.lineTo(rightBody, bottom)
            ctx.strokeStyle = root.borderColor
            ctx.globalAlpha = 0.22
            ctx.lineWidth = 1
            ctx.stroke()
            ctx.globalAlpha = 1
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root
            function onJoinWidthChanged() { contourCanvas.requestPaint() }
            function onFlushLeftChanged() { contourCanvas.requestPaint() }
            function onFlushRightChanged() { contourCanvas.requestPaint() }
            function onRailHeightChanged() { contourCanvas.requestPaint() }
            function onSideInsetChanged() { contourCanvas.requestPaint() }
            function onShadowReserveChanged() { contourCanvas.requestPaint() }
        }
    }

    Item {
        id: contentHost
        anchors.fill: parent
        anchors.leftMargin: root.leftJoinWidth + root.sideInset + 8
        anchors.rightMargin: root.rightJoinWidth + root.sideInset + 8
        anchors.topMargin: root.topInset + 2
        anchors.bottomMargin: root.bottomInset + root.shadowReserve
    }
}
