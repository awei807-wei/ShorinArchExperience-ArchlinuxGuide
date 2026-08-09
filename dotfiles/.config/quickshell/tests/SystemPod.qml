import QtQuick
import "."

// 右侧系统集群：Metrics、Tray、Power 各自独立下伸，舱间保持窄透明缝隙。
Item {
    id: root

    property bool compact: false
    property bool narrow: false
    property bool balanced: false
    property color ink: "#d9d3c9"
    property color muted: "#8e8d89"
    property color copper: "#7b6240"
    property color amber: "#dca651"

    readonly property real podGap: root.narrow ? 5 : (root.compact ? 7 : 8)
    readonly property real trayWidth: root.narrow
                                      ? 102
                                      : (root.compact ? 112 : (root.balanced ? 122 : 132))
    readonly property real powerWidth: root.narrow
                                       ? 44
                                       : (root.compact ? 48 : (root.balanced ? 52 : 56))
    readonly property real metricsWidth: Math.max(0,
                                                  root.width
                                                  - root.trayWidth
                                                  - root.powerWidth
                                                  - 2 * root.podGap)
    readonly property real metricsInset: root.narrow ? 2 : (root.compact ? 4 : (root.balanced ? 4 : 6))
    readonly property real trayInset: root.narrow ? 2 : (root.compact ? 4 : (root.balanced ? 4 : 6))

    implicitHeight: 78

    Row {
        anchors.fill: parent
        spacing: root.podGap

        // Metrics pod expands into all remaining width.
        ContourPod {
            id: metricsPod
            width: root.metricsWidth
            height: parent.height
            sideInset: root.metricsInset
            borderColor: root.copper
            highlightColor: root.amber

            Row {
                anchors.fill: parent

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
                        width: root.narrow ? 30 : (root.compact ? 36 : (root.balanced ? 38 : 46))
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

                spacing: root.narrow ? 5 : (root.compact ? 7 : (root.balanced ? 8 : 10))
            }
        }

        // Tray pod keeps utility icons together without an internal divider.
        ContourPod {
            id: trayPod
            width: root.trayWidth
            height: parent.height
            sideInset: root.trayInset
            borderColor: root.copper
            highlightColor: root.amber

            Row {
                anchors.fill: parent
                spacing: root.narrow ? 5 : (root.compact ? 5 : (root.balanced ? 7 : 7))

                Repeater {
                    model: ["discord", "telegram", "mail"]
                    delegate: UtilityIcon {
                        required property string modelData
                        kind: modelData
                        width: root.narrow ? 23 : (root.compact ? 25 : (root.balanced ? 27 : 29))
                        height: root.narrow ? 23 : (root.compact ? 25 : (root.balanced ? 27 : 29))
                        radius: root.narrow ? 6 : 7
                        anchors.verticalCenter: parent.verticalCenter
                        ink: root.ink
                        copper: root.copper
                    }
                }
            }
        }

        // Power pod is intentionally just a centered line icon inside its own contour.
        ContourPod {
            id: powerPod
            width: root.powerWidth
            height: parent.height
            sideInset: 0
            borderColor: root.copper
            highlightColor: root.amber

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
