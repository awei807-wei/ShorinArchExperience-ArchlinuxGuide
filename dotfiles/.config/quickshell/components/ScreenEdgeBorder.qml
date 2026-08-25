import QtQuick
import Quickshell
import Quickshell.Wayland

// 改编自 Brainitech/Brain_Shell 的 Border.qml（MIT），
// 提交 f90fc9c6bdfb25568c731ea1158d3f8e4b7a6e20。
// 顶部 flare 与 Bar 方形外端相接，再以内凹 R 角收束为屏幕侧边细轨。
PanelWindow {
    id: root

    property string edge: "left"
    property real barBottom: 40
    property real thickness: 6
    property real cornerRadius: 17
    property color surfaceColor: "#101010"
    readonly property bool leftEdge: edge === "left"

    implicitWidth: thickness + cornerRadius
    color: "transparent"
    exclusiveZone: -1
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        bottom: true
        left: root.leftEdge
        right: !root.leftEdge
    }
    margins.top: barBottom
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: noInput }

    Item {
        id: noInput
        width: 0
        height: 0
    }

    Canvas {
        id: shape

        anchors.fill: parent
        antialiasing: true

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()

            const w = width
            const h = height
            const t = Math.max(0, Math.min(root.thickness, w))
            const r = Math.max(0, Math.min(root.cornerRadius, w - t))

            ctx.beginPath()
            ctx.fillStyle = root.surfaceColor

            if (root.leftEdge) {
                ctx.moveTo(0, 0)
                ctx.lineTo(t + r, 0)
                ctx.arcTo(t, 0, t, r, r)
                ctx.lineTo(t, h)
                ctx.lineTo(0, h)
            } else {
                ctx.moveTo(w, 0)
                ctx.lineTo(w - t - r, 0)
                ctx.arcTo(w - t, 0, w - t, r, r)
                ctx.lineTo(w - t, h)
                ctx.lineTo(w, h)
            }

            ctx.closePath()
            ctx.fill()
        }

        Connections {
            target: root
            function onEdgeChanged() { shape.requestPaint() }
            function onThicknessChanged() { shape.requestPaint() }
            function onCornerRadiusChanged() { shape.requestPaint() }
            function onSurfaceColorChanged() { shape.requestPaint() }
        }
    }
}
