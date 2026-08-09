import QtQuick

Rectangle {
    id: root

    property string kind: "mail"
    property color ink: "#d9d3c9"
    property color copper: "#7b6240"
    property color telegramInk: "#9bc8dc"

    implicitWidth: 29
    implicitHeight: 29
    radius: 7
    color: "#1a1d1f"
    border.width: 1
    border.color: root.copper

    Canvas {
        id: canvas
        anchors.centerIn: parent
        width: 16
        height: 16

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = root.kind === "telegram" ? root.telegramInk : root.ink
            ctx.fillStyle = ctx.strokeStyle
            ctx.lineWidth = 1.25
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            if (root.kind === "discord") {
                ctx.beginPath()
                ctx.moveTo(3, 5)
                ctx.quadraticCurveTo(8, 2, 13, 5)
                ctx.lineTo(14, 11)
                ctx.quadraticCurveTo(8, 15, 2, 11)
                ctx.closePath()
                ctx.stroke()
                ctx.beginPath()
                ctx.arc(6, 8, 0.9, 0, Math.PI * 2)
                ctx.arc(10, 8, 0.9, 0, Math.PI * 2)
                ctx.fill()
            } else if (root.kind === "telegram") {
                ctx.beginPath()
                ctx.moveTo(2, 8)
                ctx.lineTo(14, 3)
                ctx.lineTo(10, 13)
                ctx.lineTo(7, 9)
                ctx.closePath()
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(7, 9)
                ctx.lineTo(13, 4)
                ctx.stroke()
            } else {
                ctx.beginPath()
                ctx.rect(2.5, 4, 11, 8)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(3, 5)
                ctx.lineTo(8, 9)
                ctx.lineTo(13, 5)
                ctx.stroke()
            }
        }
    }

    onKindChanged: canvas.requestPaint()
    onInkChanged: canvas.requestPaint()
    onCopperChanged: canvas.requestPaint()
    onTelegramInkChanged: canvas.requestPaint()
}
