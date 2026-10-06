import "../config" as Config
import QtQuick
import QtQuick.Shapes

// 屏幕右边缘连体展开轮廓：
// 贴紧屏幕右边界，包含平滑的内凹反圆角（Flare）与外凸圆角（Radius），
// 使用 Shape.CurveRenderer 进行 GPU 加速抗锯齿渲染。
Shape {
    id: root

    property real depth: 220
    property real bodyHeight: 270
    property real flare: 16
    property real radius: 16
    property color surfaceColor: Config.Theme.surface

    preferredRendererType: Shape.CurveRenderer
    asynchronous: false

    readonly property real w: width
    readonly property real h: height
    readonly property real centerY: h / 2

    readonly property real safeDepth: Math.max(0.001, Math.min(w, depth))
    readonly property real safeBodyH: Math.max(0.001, Math.min(h - 2 * flare, bodyHeight))
    readonly property real safeFlare: Math.max(0.001, Math.min(flare, safeDepth, safeBodyH / 2))
    readonly property real safeRadius: Math.max(0.001, Math.min(radius, safeDepth, safeBodyH / 2))

    // 路径推导（以 SVG 椭圆弧与线条表示，无缝封闭）：
    // 1. (w, topFlareY) 开始
    // 2. A flare flare 0 0 0 (w - flare, topBodyY) [向左下内凹]
    // 3. L (w - depth + radius, topBodyY)
    // 4. A radius radius 0 0 0 (w - depth, topBodyY + radius) [向左下凸起]
    // 5. L (w - depth, bottomBodyY - radius)
    // 6. A radius radius 0 0 0 (w - depth + radius, bottomBodyY) [向右下凸起]
    // 7. L (w - flare, bottomBodyY)
    // 8. A flare flare 0 0 0 (w, bottomFlareY) [向右下内凹贴边]
    // 9. L (w, topFlareY) Z [贴右边缘闭合]
    readonly property real topBodyY: centerY - safeBodyH / 2
    readonly property real bottomBodyY: centerY + safeBodyH / 2
    readonly property real topFlareY: topBodyY - safeFlare
    readonly property real bottomFlareY: bottomBodyY + safeFlare

    readonly property string shapePathSvg: {
        const topF = topFlareY
        const botF = bottomFlareY
        const topB = topBodyY
        const botB = bottomBodyY
        const d = safeDepth
        const f = safeFlare
        const r = safeRadius

        return "M " + w + " " + topF +
               " A " + f + " " + f + " 0 0 0 " + (w - f) + " " + topB +
               " L " + (w - d + r) + " " + topB +
               " A " + r + " " + r + " 0 0 0 " + (w - d) + " " + (topB + r) +
               " L " + (w - d) + " " + (botB - r) +
               " A " + r + " " + r + " 0 0 0 " + (w - d + r) + " " + botB +
               " L " + (w - f) + " " + botB +
               " A " + f + " " + f + " 0 0 0 " + w + " " + botF +
               " L " + w + " " + topF +
               " Z"
    }

    ShapePath {
        strokeColor: "transparent"
        fillColor: root.surfaceColor

        PathSvg {
            path: root.shapePathSvg
        }
    }
}