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
    property real joinRadius: 20
    property bool flushLeft: false
    property bool flushRight: false
    property real railHeight: 9
    property real topInset: 12
    property real bottomInset: 10
    property real shadowReserve: 5

    implicitHeight: 78

    readonly property real leftJoin: root.flushLeft ? 0 : root.joinRadius
    readonly property real rightJoin: root.flushRight ? 0 : root.joinRadius

    Canvas {
        id: contourCanvas
        anchors.fill: parent
        antialiasing: true

        function drawContour(ctx, offsetY) {
            const w = root.width
            const h = root.height
            const join = Math.min(root.joinRadius,
                                 Math.max(12, h - root.railHeight - 24))
            const leftJoin = root.flushLeft ? 0 : join
            const rightJoin = root.flushRight ? 0 : join
            const top = Math.max(0, offsetY)
            const railBottom = root.railHeight + offsetY
            const bottom = h - root.shadowReserve - 2 + offsetY
            const bottomRadius = Math.min(14, Math.max(10, h * 0.2))
            const lower = Math.max(railBottom + Math.max(leftJoin, rightJoin),
                                   bottom - bottomRadius)
            const leftBody = leftJoin
            const rightBody = w - rightJoin

            ctx.beginPath()
            // The top edge belongs to the rail and is deliberately not
            // highlighted or outlined separately.
            ctx.moveTo(0, top)
            ctx.lineTo(w, top)
            ctx.lineTo(w, railBottom)

            if (rightJoin > 0) {
                // Outer top-right point -> body right edge, clockwise quarter.
                ctx.arc(w - rightJoin, root.railHeight + offsetY,
                        rightJoin, 0, Math.PI / 2)
            }

            ctx.lineTo(rightBody, lower)
            ctx.quadraticCurveTo(rightBody, bottom,
                                 Math.max(leftBody + bottomRadius, rightBody - bottomRadius),
                                 bottom)
            ctx.lineTo(Math.min(rightBody - bottomRadius, leftBody + bottomRadius), bottom)
            ctx.quadraticCurveTo(leftBody, bottom,
                                 leftBody, lower)

            if (leftJoin > 0) {
                // Body left edge -> outer top-left point, counter-clockwise quarter.
                ctx.arc(leftJoin, root.railHeight + offsetY,
                        leftJoin, Math.PI / 2, Math.PI)
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
            const leftBody = root.leftJoin
            const rightBody = root.width - root.rightJoin
            const bottom = root.height - root.shadowReserve - 2
            const bottomRadius = Math.min(14, Math.max(10, root.height * 0.2))
            const lower = Math.max(root.railHeight
                                   + Math.max(root.leftJoin, root.rightJoin),
                                   bottom - bottomRadius)
            ctx.moveTo(leftBody, lower)
            ctx.lineTo(leftBody, bottom - 2)
            ctx.quadraticCurveTo(leftBody, bottom,
                                 Math.min(rightBody - bottomRadius, leftBody + bottomRadius),
                                 bottom)
            ctx.lineTo(Math.max(leftBody + bottomRadius, rightBody - bottomRadius), bottom)
            ctx.quadraticCurveTo(rightBody, bottom,
                                 rightBody, lower)
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
            function onJoinRadiusChanged() { contourCanvas.requestPaint() }
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
        anchors.leftMargin: root.leftJoin + root.sideInset + 8
        anchors.rightMargin: root.rightJoin + root.sideInset + 8
        anchors.topMargin: root.topInset + 2
        anchors.bottomMargin: root.bottomInset + root.shadowReserve
    }
}
