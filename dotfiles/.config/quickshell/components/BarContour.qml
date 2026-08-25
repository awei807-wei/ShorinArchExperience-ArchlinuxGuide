import QtQuick

// 几何改编自 Brainitech/Brain_Shell 的 SeamlessBarShape.qml（MIT），
// 提交 f90fc9c6bdfb25568c731ea1158d3f8e4b7a6e20。
// 单个闭合路径可避免顶部连接带与三个岛体之间出现抗锯齿接缝。
Canvas {
    id: root

    property real leftWidth: 180
    property real centerWidth: 240
    property real centerOffset: 0
    property real rightWidth: 180
    property real notchHeight: 40
    property real notchRadius: 15
    property real topBorderWidth: 6
    property color surfaceColor: "#101010"

    readonly property real centerStart: (width - centerWidth) / 2 + centerOffset
    readonly property real centerEnd: centerStart + centerWidth
    readonly property real rightStart: width - rightWidth

    antialiasing: true

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onLeftWidthChanged: requestPaint()
    onCenterWidthChanged: requestPaint()
    onCenterOffsetChanged: requestPaint()
    onRightWidthChanged: requestPaint()
    onNotchHeightChanged: requestPaint()
    onNotchRadiusChanged: requestPaint()
    onTopBorderWidthChanged: requestPaint()
    onSurfaceColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();

        const h = Math.max(0, Math.min(root.notchHeight, height));
        const b = Math.max(0, Math.min(root.topBorderWidth, h));
        const maximumRadius = Math.max(0, (h - b) / 2);
        const r = Math.max(0, Math.min(root.notchRadius, maximumRadius));
        const leftEnd = Math.max(r, Math.min(root.leftWidth, width));
        const centerStart = Math.max(r, Math.min(root.centerStart, width - r));
        const centerEnd = Math.max(centerStart + 2 * r,
                                   Math.min(root.centerEnd, width - r));
        const rightStart = Math.max(r, Math.min(root.rightStart, width - r));

        ctx.beginPath();
        ctx.fillStyle = root.surfaceColor;

        // 左岛贴屏幕边缘，只在右侧绘制下凸圆角与上部反 R 角。
        ctx.moveTo(0, h);
        ctx.lineTo(leftEnd - r, h);
        ctx.arcTo(leftEnd, h, leftEnd, h - r, r);
        ctx.lineTo(leftEnd, b + r);
        ctx.arcTo(leftEnd, b, leftEnd + r, b, r);

        // 中岛两侧都由上部内凹圆角、短直边和下部外凸圆角组成。
        ctx.lineTo(centerStart - r, b);
        ctx.arcTo(centerStart, b, centerStart, b + r, r);
        ctx.lineTo(centerStart, h - r);
        ctx.arcTo(centerStart, h, centerStart + r, h, r);
        ctx.lineTo(centerEnd - r, h);
        ctx.arcTo(centerEnd, h, centerEnd, h - r, r);
        ctx.lineTo(centerEnd, b + r);
        ctx.arcTo(centerEnd, b, centerEnd + r, b, r);

        // 右岛镜像左岛，并贴住屏幕右边缘。
        ctx.lineTo(rightStart - r, b);
        ctx.arcTo(rightStart, b, rightStart, b + r, r);
        ctx.lineTo(rightStart, h - r);
        ctx.arcTo(rightStart, h, rightStart + r, h, r);
        ctx.lineTo(width, h);

        ctx.lineTo(width, 0);
        ctx.lineTo(0, 0);
        ctx.closePath();
        ctx.fill();
    }
}
