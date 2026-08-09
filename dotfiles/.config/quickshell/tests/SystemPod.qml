import QtQuick
import "."

// 右侧系统集群：Metrics、Tray、Power 共用一条连续 rail-attached 轮廓。
// 右侧主体 flush 到屏幕边缘，只在左侧保留 rail 到主体的内切转角。
Item {
    id: root

    property bool compact: false
    property bool narrow: false
    property bool balanced: false
    property real joinRadius: 20
    property real railHeight: 9
    property color ink: "#d9d3c9"
    property color muted: "#8e8d89"
    property color copper: "#7b6240"
    property color amber: "#dca651"

    readonly property real groupGap: root.narrow ? 5 : (root.compact ? 7 : 8)
    readonly property real trayWidth: root.narrow
                                      ? 102
                                      : (root.compact ? 112 : (root.balanced ? 122 : 132))
    readonly property real powerWidth: root.narrow
                                       ? 44
                                       : (root.compact ? 48 : (root.balanced ? 52 : 56))
    readonly property real outerInset: root.narrow
                                       ? 2
                                       : (root.compact ? 4 : (root.balanced ? 4 : 6))
    readonly property real trayInset: root.narrow
                                      ? 2
                                      : (root.compact ? 4 : (root.balanced ? 4 : 6))
    readonly property real contentWidth: Math.max(0,
                                                  root.width
                                                  - root.joinRadius
                                                  - 2 * (root.outerInset + 8))
    readonly property real trayContentWidth: Math.max(
                                                root.trayWidth
                                                - 2 * (root.trayInset + 8),
                                                3 * (root.narrow ? 23
                                                   : (root.compact ? 25
                                                      : (root.balanced ? 27 : 29)))
                                                + 2 * (root.narrow ? 5 : 7))
    readonly property real powerContentWidth: Math.max(
                                                 root.powerWidth - 16,
                                                 root.narrow ? 18 : 20)
    readonly property real metricsContentWidth: Math.max(0,
                                                         root.contentWidth
                                                         - root.trayContentWidth
                                                         - root.powerContentWidth
                                                         - 2 * root.groupGap)

    implicitHeight: 78

    ContourPod {
        id: unifiedContour
        anchors.fill: parent
        sideInset: root.outerInset
        joinRadius: root.joinRadius
        railHeight: root.railHeight
        flushLeft: false
        flushRight: true
        borderColor: root.copper
        highlightColor: root.amber

        Item {
            id: contentLayout
            anchors.fill: parent

            Item {
                id: metricsRegion
                x: 0
                width: root.metricsContentWidth
                height: parent.height

                Row {
                    anchors.fill: parent
                    spacing: root.narrow ? 5 : (root.compact ? 7 : (root.balanced ? 8 : 10))

                    Repeater {
                        model: root.narrow
                               ? [
                                   { label: "NET", value: "2.3K", fill: 0.76 },
                                   { label: "MEM", value: "48%", fill: 0.48 },
                                   { label: "CPU", value: "14%", fill: 0.14 }
                               ]
                               : [
                                   { label: "NET", value: "2.3K", fill: 0.76 },
                                   { label: "MEM", value: "48%", fill: 0.48 },
                                   { label: "CPU", value: "14%", fill: 0.14 },
                                   { label: "VOL", value: "42%", fill: 0.42 }
                               ]
                        delegate: Column {
                            required property var modelData
                            width: root.narrow
                                   ? 30
                                   : (root.compact ? 36 : (root.balanced ? 38 : 46))
                            spacing: 4
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: modelData.label
                                color: root.muted
                                font.family: "JetBrains Mono"
                                font.pixelSize: root.compact ? 7 : 8
                                font.letterSpacing: 0.6
                            }
                            Text {
                                text: modelData.value
                                color: root.ink
                                font.family: "JetBrains Mono"
                                font.pixelSize: root.compact ? 9 : 10
                            }
                            Rectangle {
                                width: parent.width
                                height: 2
                                color: "#2a2c2c"
                                Rectangle {
                                    width: parent.width * modelData.fill
                                    height: parent.height
                                    color: root.amber
                                    opacity: 0.86
                                }
                            }
                        }
                    }
                }
            }

            // Delicate dividers preserve information hierarchy without
            // reintroducing separate outer contours or transparent gaps.
            Rectangle {
                x: metricsRegion.x + metricsRegion.width + root.groupGap / 2
                y: 12
                width: 1
                height: Math.max(24, parent.height - 24)
                color: root.copper
                opacity: 0.58
            }

            Item {
                id: trayRegion
                x: metricsRegion.x + metricsRegion.width + root.groupGap
                width: root.trayContentWidth
                height: parent.height

                Row {
                    anchors.centerIn: parent
                    spacing: root.narrow ? 5 : (root.compact ? 5 : (root.balanced ? 7 : 7))

                    Repeater {
                        model: ["discord", "telegram", "mail"]
                        delegate: UtilityIcon {
                            required property string modelData
                            kind: modelData
                            width: root.narrow
                                   ? 23
                                   : (root.compact ? 25 : (root.balanced ? 27 : 29))
                            height: root.narrow
                                    ? 23
                                    : (root.compact ? 25 : (root.balanced ? 27 : 29))
                            radius: root.narrow ? 6 : 7
                            anchors.verticalCenter: parent.verticalCenter
                            ink: root.ink
                            copper: root.copper
                        }
                    }
                }
            }

            Rectangle {
                x: trayRegion.x + trayRegion.width + root.groupGap / 2
                y: 12
                width: 1
                height: Math.max(24, parent.height - 24)
                color: root.copper
                opacity: 0.58
            }

            Item {
                id: powerRegion
                x: trayRegion.x + trayRegion.width + root.groupGap
                width: root.powerContentWidth
                height: parent.height

                Canvas {
                    anchors.centerIn: parent
                    width: root.narrow ? 18 : 20
                    height: root.narrow ? 18 : 20

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        ctx.strokeStyle = root.ink
                        ctx.lineWidth = 1.6
                        ctx.lineCap = "round"
                        ctx.beginPath()
                        ctx.arc(width / 2, height / 2 + 1, root.narrow ? 5.8 : 6.2,
                                -Math.PI * 0.78, Math.PI * 0.78)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(width / 2, 2)
                        ctx.lineTo(width / 2, root.narrow ? 9 : 10)
                        ctx.stroke()
                    }

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                }
            }
        }
    }
}
