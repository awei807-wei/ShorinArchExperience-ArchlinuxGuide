import QtQuick

// 使用归一化坐标绘制锁屏操作图标，避免字体 baseline 与 fallback 改变视觉重心。
Canvas {
    id: root

    property string name: "power"
    property color iconColor: "white"
    property real strokeWidth: 1.8

    implicitWidth: 20
    implicitHeight: 20
    antialiasing: true

    onNameChanged: requestPaint()
    onIconColorChanged: requestPaint()
    onStrokeWidthChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)

        const size = Math.min(width, height)
        const ox = (width - size) / 2
        const oy = (height - size) / 2

        ctx.globalAlpha = 1
        ctx.strokeStyle = root.iconColor
        ctx.lineWidth = root.strokeWidth
        ctx.lineCap = "round"
        ctx.lineJoin = "round"

        if (root.name === "power") {
            ctx.beginPath()
            ctx.moveTo(ox + size * 0.5, oy + size * 0.10)
            ctx.lineTo(ox + size * 0.5, oy + size * 0.48)
            ctx.stroke()

            ctx.beginPath()
            ctx.arc(ox + size * 0.5, oy + size * 0.52, size * 0.34,
                    -Math.PI * 0.25, Math.PI * 1.25, false)
            ctx.stroke()
            return
        }

        ctx.beginPath()
        ctx.moveTo(ox + size * 0.10, oy + size * 0.50)
        ctx.bezierCurveTo(ox + size * 0.27, oy + size * 0.25,
                          ox + size * 0.73, oy + size * 0.25,
                          ox + size * 0.90, oy + size * 0.50)
        ctx.bezierCurveTo(ox + size * 0.73, oy + size * 0.75,
                          ox + size * 0.27, oy + size * 0.75,
                          ox + size * 0.10, oy + size * 0.50)
        ctx.stroke()

        ctx.beginPath()
        ctx.arc(ox + size * 0.50, oy + size * 0.50, size * 0.11,
                0, Math.PI * 2)
        ctx.stroke()

        if (root.name === "eye-off") {
            ctx.beginPath()
            ctx.moveTo(ox + size * 0.18, oy + size * 0.18)
            ctx.lineTo(ox + size * 0.82, oy + size * 0.82)
            ctx.stroke()
        }
    }
}
