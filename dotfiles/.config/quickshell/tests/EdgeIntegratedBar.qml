import QtQuick
import "."

// 仅用于预览的三舱编排层。rail 是唯一的全宽底色，舱体间保持透明。
Item {
    id: root

    readonly property color railTop: "#111518"
    readonly property color railBottom: "#090c0e"
    readonly property color ink: "#d9d3c9"
    readonly property color muted: "#8e8d89"
    readonly property color dim: "#5f625f"
    readonly property color copper: "#7b6240"
    readonly property color amber: "#dca651"

    readonly property bool compact: width < 1120
    readonly property bool narrow: width < 1000
    readonly property bool balanced: width < 1500
    readonly property real sideMargin: Math.max(14, width * 0.014)
    readonly property real leftWidth: Math.max(210, Math.min(390, width * 0.235))
    readonly property real centerWidth: width < 1000
                                        ? 200
                                        : Math.max(220, Math.min(340, width * 0.22))
    readonly property real rightWidth: width < 1000
                                       ? Math.max(288, Math.min(360, width * 0.28))
                                       : Math.max(390, Math.min(500, width * 0.31))
    // The right island owns one continuous top-edge wedge.  The original
    // rightWidth remains the body width; only the item's left bound expands.
    readonly property real rightTriangleWidth: width < 1000
                                               ? 42
                                               : (width < 1400 ? 54 : 68)
    readonly property real leftEnd: sideMargin + leftWidth
    readonly property real rightStart: width - sideMargin - rightWidth
    readonly property real rightIslandStart: rightStart - rightTriangleWidth
    readonly property real centerX: Math.max(leftEnd + 12,
                                             Math.min((width - centerWidth) / 2,
                                                      rightIslandStart - centerWidth - 12))

    implicitHeight: 88

    // The uninterrupted 14px rail is the only full-width surface.
    Rectangle {
        width: parent.width
        height: 14
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.railTop }
            GradientStop { position: 0.52; color: "#0d1113" }
            GradientStop { position: 1.0; color: root.railBottom }
        }
    }
    Rectangle {
        width: parent.width
        height: 14
        color: "#0f1315"
        opacity: 0.62
    }
    Rectangle {
        y: 12
        width: parent.width
        height: 1
        color: "#4a463c"
        opacity: 0.72
    }
    Rectangle {
        y: 13
        width: parent.width
        height: 1
        color: "#06090b"
        opacity: 0.9
    }

    // Small marks keep the rail legible in transparent gaps without filling them.
    Repeater {
        model: [root.leftEnd + 16,
                root.centerX - 22,
                root.centerX + root.centerWidth + 6,
                root.rightIslandStart - 22]
        delegate: Rectangle {
            required property real modelData
            x: modelData
            y: 11
            width: 12
            height: 1
            color: root.copper
            opacity: 0.46
        }
    }

    WorkspacePod {
        x: root.sideMargin
        y: 0
        width: root.leftWidth
        height: 78
        compact: root.compact
        narrow: root.narrow
        ink: root.ink
        muted: root.muted
        dim: root.dim
        copper: root.copper
        amber: root.amber
    }

    ClockPod {
        x: root.centerX
        y: 0
        width: root.centerWidth
        height: 78
        compact: root.compact
        narrow: root.narrow
        ink: root.ink
        muted: root.muted
        copper: root.copper
        amber: root.amber
    }

    SystemPod {
        x: root.rightIslandStart
        y: 0
        width: root.rightWidth + root.rightTriangleWidth
        height: 78
        leadingTriangleWidth: root.rightTriangleWidth
        compact: root.compact
        narrow: root.narrow
        balanced: root.balanced
        ink: root.ink
        muted: root.muted
        copper: root.copper
        amber: root.amber
    }
}
