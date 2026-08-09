import QtQuick
import "."

// 仅用于预览的三舱编排层。顶部 rail 连续贯穿全屏，功能区从 rail
// 下方直接长出；rail 以下的空档保持透明。
Item {
    id: root

    readonly property color railTop: "#101314"
    readonly property color ink: "#d9d3c9"
    readonly property color muted: "#8e8d89"
    readonly property color dim: "#5f625f"
    readonly property color copper: "#7b6240"
    readonly property color amber: "#dca651"

    readonly property bool compact: width < 1120
    readonly property bool narrow: width < 1000
    readonly property bool balanced: width < 1500
    readonly property real railHeight: 9
    readonly property real joinWidth: width < 1000 ? 18 : 20
    readonly property real leftWidth: Math.max(210, Math.min(390, width * 0.235))
    readonly property real centerWidth: width < 1000
                                        ? 200
                                        : Math.max(220, Math.min(340, width * 0.22))
    readonly property real rightWidth: width < 1000
                                       ? Math.max(288, Math.min(360, width * 0.28))
                                       : Math.max(390, Math.min(500, width * 0.31))
    // Width values describe the vertical body. Each item grows outward by
    // joinWidth only carries the rail-to-body full-height quarter ellipse.
    readonly property real leftEnd: leftWidth
    readonly property real rightStart: width - rightWidth
    readonly property real centerX: Math.max(leftEnd + 12,
                                             Math.min((width - centerWidth) / 2,
                                                      rightStart - centerWidth - 12))

    implicitHeight: 88

    // The uninterrupted 9px rail is the only full-width surface.
    Rectangle {
        width: parent.width
        height: root.railHeight
        color: root.railTop
    }

    WorkspacePod {
        x: 0
        y: 0
        width: root.leftWidth + root.joinWidth
        height: 78
        joinWidth: root.joinWidth
        railHeight: root.railHeight
        compact: root.compact
        narrow: root.narrow
        ink: root.ink
        muted: root.muted
        dim: root.dim
        copper: root.copper
        amber: root.amber
    }

    ClockPod {
        x: root.centerX - root.joinWidth
        y: 0
        width: root.centerWidth + 2 * root.joinWidth
        height: 78
        joinWidth: root.joinWidth
        railHeight: root.railHeight
        compact: root.compact
        narrow: root.narrow
        ink: root.ink
        muted: root.muted
        copper: root.copper
        amber: root.amber
    }

    SystemPod {
        x: root.rightStart - root.joinWidth
        y: 0
        width: root.rightWidth + root.joinWidth
        height: 78
        joinWidth: root.joinWidth
        railHeight: root.railHeight
        compact: root.compact
        narrow: root.narrow
        balanced: root.balanced
        ink: root.ink
        muted: root.muted
        copper: root.copper
        amber: root.amber
    }
}
