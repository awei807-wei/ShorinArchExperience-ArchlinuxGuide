import QtQuick
import "../"

// Draws a popup background that "melts" into whichever edge(s) it's attached to.
Canvas {
    id: root

    property string attachedEdge: "top"
    property color color: Theme.background
    
    // Normal corner radius for the edges away from the notch
    property int radius: Theme.cornerRadius
    
    // Custom dimensions for the outward "melt" (concave corners)
    // Increase flareHeight to make the corners "higher" / stretch further
    property int flareWidth: Theme.cornerRadius
    property int flareHeight: Theme.cornerRadius

    onWidthChanged:        requestPaint()
    onHeightChanged:       requestPaint()
    onAttachedEdgeChanged: requestPaint()
    onColorChanged:        requestPaint()
    onFlareWidthChanged:   requestPaint()
    onFlareHeightChanged:  requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()

        var w = width
        var h = height
        var r = radius
        var fw = flareWidth
        var fh = flareHeight

        // 半径水平约束：避免左右圆弧相交。垂直方向不收缩——共享外轮廓
        // 场景下（attachedEdge "top"）低高度 + 大半径是合法状态，
        // 由下方虚拟顶边绘制大圆角的可见下段
        r = Math.max(0, Math.min(r, (w - 2 * fw) / 2))

        ctx.beginPath()
        ctx.fillStyle = root.color

        // We use quadraticCurveTo(cpx, cpy, x, y) for the flares to allow
        // asymmetric stretching (making them higher/wider than a perfect circle).
        switch (root.attachedEdge) {

        case "left":
            // Body inset by fw on the Left. Flare stretches vertically by fh.
            ctx.moveTo(0, 0)
            ctx.quadraticCurveTo(0, fh, fw, fh)       // outward flare top-left
            ctx.lineTo(w - r, fh)
            ctx.arcTo(w, fh, w, fh + r, r)            // normal top-right
            ctx.lineTo(w, h - fh - r)
            ctx.arcTo(w, h - fh, w - r, h - fh, r)    // normal bottom-right
            ctx.lineTo(fw, h - fh)
            ctx.quadraticCurveTo(0, h - fh, 0, h)     // outward flare bottom-left
            ctx.closePath()
            break

        case "right":
            // Body inset by fw on the Right. Flare stretches vertically by fh.
            ctx.moveTo(w, 0)
            ctx.quadraticCurveTo(w, fh, w - fw, fh)   // outward flare top-right
            ctx.lineTo(r, fh)
            ctx.arcTo(0, fh, 0, fh + r, r)            // normal top-left
            ctx.lineTo(0, h - fh - r)
            ctx.arcTo(0, h - fh, r, h - fh, r)        // normal bottom-left
            ctx.lineTo(w - fw, h - fh)
            ctx.quadraticCurveTo(w, h - fh, w, h)     // outward flare bottom-right
            ctx.closePath()
            break

        case "top": {
            // 共享外轮廓支持：高度不足以容纳完整底角圆弧（收拢末段
            // h < r）时，顶边上移到圆弧起点之上形成“虚拟顶边”，Canvas
            // 自动裁掉窗口外的部分，窗口内呈现的正是大圆角圆弧的下段；
            // 正常高度（h >= r）时 top = 0，路径与原始版本一致
            const top = Math.min(0, h - r)
            const bodyTop = top + fh
            ctx.moveTo(0, top)
            ctx.quadraticCurveTo(fw, top, fw, bodyTop)
            ctx.lineTo(fw, h - r)
            ctx.arcTo(fw, h, fw + r, h, r)            // normal bottom-left
            ctx.lineTo(w - fw - r, h)
            ctx.arcTo(w - fw, h, w - fw, h - r, r)    // normal bottom-right
            ctx.lineTo(w - fw, bodyTop)
            ctx.quadraticCurveTo(w - fw, top, w, top) // outward flare top-right
            ctx.closePath()
            break
        }

        case "bottom":
            // Body inset by fw on Left/Right. Flare stretches horizontally by fw, vertically by fh.
            ctx.moveTo(0, h)
            ctx.quadraticCurveTo(fw, h, fw, h - fh)   // outward flare bottom-left
            ctx.lineTo(fw, r)
            ctx.arcTo(fw, 0, fw + r, 0, r)            // normal top-left
            ctx.lineTo(w - fw - r, 0)
            ctx.arcTo(w - fw, 0, w - fw, r, r)        // normal top-right
            ctx.lineTo(w - fw, h - fh)
            ctx.quadraticCurveTo(w - fw, h, w, h)     // outward flare bottom-right
            ctx.closePath()
            break

        case "bottom-right":
            // Popup sits in the bottom-right screen corner.
            // Canvas: (popupWidth + fw) × (popupHeight + fh)
            //
            // Body top edge at y=fh, body left edge at x=fw.
            // Right and bottom edges are flush with screen borders.
            //
            // fw pixels on LEFT  → bottom-left flare zone
            // fh pixels on TOP   → top-right flare zone
            //
            // Flares:
            //   top-right:   concave melt into right border
            //   bottom-left: concave melt into bottom border
            //   top-left:    normal convex rounded corner
            //   bottom-right: square — both border strips physically cover it
            //
            // Content safe zone: x ≥ fw, y ≥ fh  (margins handle both flare corners)

            // 1. Start top edge just after top-left radius
            ctx.moveTo(fw + r, fh)
            // 2. Top edge rightward to the flare start
            ctx.lineTo(w - fw, fh)
            // 3. Top-right flare: concave melt into the right border
            ctx.quadraticCurveTo(w, fh, w, 0)
            // 4. Right edge straight down (flush with right screen border)
            ctx.lineTo(w, h)
            // 5. Bottom edge straight left (flush with bottom screen border)
            ctx.lineTo(0, h)
            // 6. Bottom-left flare: concave melt into the bottom border
            ctx.quadraticCurveTo(fw, h, fw, h - fh)
            // 7. Left edge straight up to the top-left corner
            ctx.lineTo(fw, fh + r)
            // 8. Top-left: standard convex rounded corner
            ctx.arcTo(fw, fh, fw + r, fh, r)
            ctx.closePath()
            break
        }

        ctx.fill()
    }
}