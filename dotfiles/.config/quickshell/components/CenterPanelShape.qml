import QtQuick
import QtQuick.Shapes

// 中岛面板背景 — 共享外轮廓的 Shape 实现（替代 PopupShape 的 Canvas
// 路线，消除动画期间每帧全幅软件栅格化 + 纹理上传）。
// 平顶矩形：无凹角耳朵；底角半径由共享轮廓随进度插值（15 → 17）。
// 高度不足以容纳完整圆弧（收拢末段 h < r）时，顶边上移为虚拟顶边，
// 超出 sizer 的部分由 clip 裁掉，窗口内呈现的正是大圆角圆弧的下段。
Shape {
    id: root

    property color fillColor: "#101010"
    property real radius: 15

    preferredRendererType: Shape.CurveRenderer
    asynchronous: false

    // 虚拟顶边：h < r 时为负，底角圆弧的起点越过窗口顶边
    readonly property real topEdge: Math.min(0, height - radius)
    // 半径水平约束：避免左右圆弧相交
    readonly property real effRadius:
        Math.max(0, Math.min(radius, width / 2))

    ShapePath {
        strokeColor: "transparent"
        fillColor: root.fillColor

        PathSvg {
            path: "M 0 " + root.topEdge +
                  " L 0 " + (root.height - root.effRadius) +
                  " A " + root.effRadius + " " + root.effRadius +
                  " 0 0 0 " + root.effRadius + " " + root.height +
                  " L " + (root.width - root.effRadius) + " " + root.height +
                  " A " + root.effRadius + " " + root.effRadius +
                  " 0 0 0 " + root.width + " " + (root.height - root.effRadius) +
                  " L " + root.width + " " + root.topEdge +
                  " Z"
        }
    }
}
