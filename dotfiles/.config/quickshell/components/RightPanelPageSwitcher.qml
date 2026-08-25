import "../config" as Config
import QtQuick

// 兼容旧调用方的薄包装。实际轨道和交互实现位于 RightPanelTabs。
Item {
    id: root

    property int currentPage: 0
    property bool reducedMotion: false
    property color surfaceColor: Qt.rgba(1, 1, 1, 0.035)
    property color selectedColor: Qt.rgba(1, 1, 1, 0.13)
    property color textColor: Config.Theme.textPrimary
    property color mutedColor: Config.Theme.textMuted
    readonly property real tabsWidth: tabs.width

    signal pageRequested(int page)

    implicitHeight: Config.BarTuning.rightPanelFooterHeight
    height: implicitHeight

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Config.Theme.outlineVariant
    }

    RightPanelTabs {
        id: tabs

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        // root 在生产布局中左右各缩进 rightPanelPaddingH；把这部分
        // 加回后再取 50%，确保 560px 最小面板下也不超宽。
        width: Math.min(
            Config.BarTuning.rightPanelTabsWidth,
            (root.width + Config.BarTuning.rightPanelPaddingH * 2) * 0.5
        )
        currentIndex: root.currentPage
        reducedMotion: root.reducedMotion
        trackColor: root.surfaceColor
        indicatorColor: root.selectedColor
        textColor: root.textColor
        mutedColor: root.mutedColor
        onIndexRequested: index => root.pageRequested(index)
    }
}
