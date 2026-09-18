import QtQuick
import QtQuick.Shapes

// 几何改编自 Brainitech/Brain_Shell 的 SeamlessBarShape.qml（MIT），
// 绘制后端为 Shape/ShapePath（GPU 几何 + 曲线抗锯齿），替代原 Canvas
// 的每帧全幅软件栅格化 + 纹理上传。路径允许超出画布（中岛共享轮廓
// 下移段），超出部分由窗口边界裁切；面板窗口绘制同一轮廓的其余部分。
// 单个闭合路径可避免顶部连接带与三个岛体之间出现抗锯齿接缝。
Shape {
    id: root

    property real leftWidth: 180
    property real centerWidth: 240
    property real centerOffset: 0
    property real rightWidth: 180
    // 中岛底边的共享外轮廓：底边随进度下移（岛底 40 → 面板底
    // 40+dashboardHeight），底角半径随动（15 → cornerRadius）。
    // Bar 与面板窗口各自绘制同一轮廓落在自己窗口内的部分
    property real centerBottomY: notchHeight
    property real centerBottomRadius: notchRadius
    property real notchHeight: 40
    property real notchRadius: 15
    property real topBorderWidth: 6
    property color surfaceColor: "#101010"

    preferredRendererType: Shape.CurveRenderer
    asynchronous: false

    // 与原 Canvas onPaint 相同的钳制
    readonly property real b:
        Math.max(0, Math.min(topBorderWidth, notchHeight))
    readonly property real r:
        Math.max(0, Math.min(notchRadius, (notchHeight - b) / 2))
    readonly property real leftEnd:
        Math.max(r, Math.min(leftWidth, width))
    readonly property real centerStart:
        Math.max(r, Math.min((width - centerWidth) / 2 + centerOffset,
                             width - r))
    readonly property real centerEnd:
        Math.max(centerStart + 2 * r,
                 Math.min((width - centerWidth) / 2 + centerOffset
                          + centerWidth, width - r))
    readonly property real rightStart:
        Math.max(r, Math.min(width - rightWidth, width - r))

    // 与原 onPaint 路径一致的 SVG 序列；arcTo 切圆弧已换算为 SVG 椭圆弧
    //（large-arc=0，sweep 由行进方向转折方向决定，左/底外凸角 0、
    // 顶部内凹角 1）
    readonly property string outlinePath:
        "M 0 " + notchHeight +
        " L " + (leftEnd - r) + " " + notchHeight +
        " A " + r + " " + r + " 0 0 0 " + leftEnd + " " + (notchHeight - r) +
        " L " + leftEnd + " " + (b + r) +
        " A " + r + " " + r + " 0 0 1 " + (leftEnd + r) + " " + b +
        " L " + (centerStart - r) + " " + b +
        " A " + r + " " + r + " 0 0 1 " + centerStart + " " + (b + r) +
        " L " + centerStart + " " + (centerBottomY - centerBottomRadius) +
        " A " + centerBottomRadius + " " + centerBottomRadius +
        " 0 0 0 " + (centerStart + centerBottomRadius) + " " + centerBottomY +
        " L " + (centerEnd - centerBottomRadius) + " " + centerBottomY +
        " A " + centerBottomRadius + " " + centerBottomRadius +
        " 0 0 0 " + centerEnd + " " + (centerBottomY - centerBottomRadius) +
        " L " + centerEnd + " " + (b + r) +
        " A " + r + " " + r + " 0 0 1 " + (centerEnd + r) + " " + b +
        " L " + (rightStart - r) + " " + b +
        " A " + r + " " + r + " 0 0 1 " + rightStart + " " + (b + r) +
        " L " + rightStart + " " + (notchHeight - r) +
        " A " + r + " " + r + " 0 0 0 " + (rightStart + r) + " " + notchHeight +
        " L " + width + " " + notchHeight +
        " L " + width + " 0" +
        " L 0 0" +
        " Z"

    ShapePath {
        strokeColor: "transparent"
        fillColor: root.surfaceColor

        PathSvg { path: root.outlinePath }
    }
}
