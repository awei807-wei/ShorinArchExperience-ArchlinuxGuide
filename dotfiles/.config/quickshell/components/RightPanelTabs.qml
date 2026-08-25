import "../config" as Config
import QtQuick

// 右侧面板底部的紧凑分段切换器。
// 轨道尺寸由 BarTuning 统一管理；子项只负责透明点击和键盘焦点，
// 选中态由一个指示器表达，避免两个半宽背景把页脚撑成两块大按钮。
Item {
    id: root

    property int currentIndex: 0
    property bool reducedMotion: false

    // 保留可换肤接口，默认值对应右侧面板的低对比表面。
    property color trackColor: Qt.rgba(1, 1, 1, 0.035)
    property color trackBorderColor: Qt.rgba(1, 1, 1, 0.07)
    property color indicatorColor: Qt.rgba(1, 1, 1, 0.13)
    property color textColor: Config.Theme.textPrimary
    property color mutedColor: Config.Theme.textMuted

    signal indexRequested(int index)

    readonly property int tabCount: 2
    readonly property int normalizedIndex: Math.max(0, Math.min(
        root.tabCount - 1,
        root.currentIndex
    ))
    readonly property real cellWidth: (root.width - 4) / root.tabCount

    // 这里使用固定轨道尺寸，不随面板主体宽度拉伸。
    width: Config.BarTuning.rightPanelTabsWidth
    height: Config.BarTuning.rightPanelTabsHeight
    implicitWidth: Config.BarTuning.rightPanelTabsWidth
    implicitHeight: Config.BarTuning.rightPanelTabsHeight

    Accessible.name: "Control center page switcher"

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: root.trackColor
        border.width: 1
        border.color: root.trackBorderColor
    }

    Rectangle {
        id: indicator

        x: 2 + root.normalizedIndex * root.cellWidth
        y: 2
        width: root.cellWidth
        height: root.height - 4
        radius: height / 2
        color: root.indicatorColor

        Behavior on x {
            enabled: !root.reducedMotion
                && Config.BarTuning.panelTabIndicatorDuration > 0

            NumberAnimation {
                duration: Config.BarTuning.panelTabIndicatorDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    Repeater {
        id: tabRepeater

        model: [
            { "index": 0, "label": "CONTROL" },
            { "index": 1, "label": "HISTORY" }
        ]

        delegate: Item {
            id: tabButton

            required property int index
            required property var modelData

            readonly property bool selected: root.normalizedIndex === modelData.index
            readonly property bool hovered: tabMouse.containsMouse
            readonly property bool pressed: tabMouse.pressed

            x: index * root.cellWidth
            width: root.cellWidth
            height: root.height

            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: modelData.label
            Accessible.description: selected
                ? modelData.label + " page selected"
                : "Switch to " + modelData.label + " page"
            Accessible.selected: selected

            // 键盘焦点只画一圈细边，不再生成第二个选中背景。
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: height / 2
                color: "transparent"
                border.width: tabButton.activeFocus ? 1 : 0
                border.color: Qt.rgba(1, 1, 1, 0.42)
                opacity: tabButton.activeFocus ? 1 : 0

                Behavior on opacity {
                    enabled: !root.reducedMotion
                    NumberAnimation {
                        duration: Config.Theme.animFast
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: modelData.label
                font.family: "JetBrains Mono"
                font.pixelSize: 11
                font.weight: tabButton.selected ? Font.DemiBold : Font.Medium
                font.letterSpacing: 1.4
                color: tabButton.selected
                    ? root.textColor
                    : tabButton.hovered || tabButton.pressed
                        ? Qt.lighter(root.mutedColor, 1.2)
                        : root.mutedColor

                Behavior on color {
                    enabled: !root.reducedMotion
                    ColorAnimation {
                        duration: Config.Theme.animFast
                    }
                }
            }

            // 两个区域均保持透明，只承载点击、悬停和焦点，不绘制半宽选中块。
            MouseArea {
                id: tabMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    tabButton.forceActiveFocus()
                    root.indexRequested(modelData.index)
                }
            }

            Keys.onPressed: event => {
                let nextIndex = -1

                if (event.key === Qt.Key_Return
                    || event.key === Qt.Key_Enter
                    || event.key === Qt.Key_Space) {
                    root.indexRequested(modelData.index)
                    event.accepted = true
                    return
                }

                if (event.key === Qt.Key_Left || event.key === Qt.Key_Up)
                    nextIndex = Math.max(0, modelData.index - 1)
                else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down)
                    nextIndex = Math.min(root.tabCount - 1, modelData.index + 1)

                if (nextIndex >= 0) {
                    root.focusTab(nextIndex)
                    root.indexRequested(nextIndex)
                    event.accepted = true
                }
            }
        }
    }

    function focusTab(index) {
        const clampedIndex = Math.max(0, Math.min(root.tabCount - 1, index))
        const tab = tabRepeater.itemAt(clampedIndex)
        if (tab)
            tab.forceActiveFocus()
    }
}
