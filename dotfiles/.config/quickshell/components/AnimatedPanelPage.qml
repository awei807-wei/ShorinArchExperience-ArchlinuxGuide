import "../config" as Config
import QtQuick

// 常驻页面包装器：把整页作为一张卡片做推拉、淡入和轻微缩放，
// 不销毁/重建页面实例，也不重新播放外层面板的开合动画。
// 页面始终保持 visible，只用透明度、位移和缩放切换：通过 visible
// 卸载/重建整页场景图曾在切页时造成 90ms 的单帧停顿。
Item {
    id: root

    property bool active: false
    property bool reducedMotion: false
    // 预热期：以 0.001 的下限透明度保持渲染（低于 0.001 的子树会被
    // 场景图整体跳过），让非当前页也提前建好图层与管线
    property bool prewarm: false
    // Control 从左侧退场，History 传入正值从右侧退场。
    property real inactiveX: -Config.BarTuning.panelPageCardOffset
    property real inactiveScale:
        Config.BarTuning.panelPageCardInactiveScale
    property real transitionProgress: active ? 1 : 0

    readonly property real cardX: contentHost.x
    readonly property real cardScale: contentHost.scale
    readonly property bool contentVisible: transitionProgress > 0.001
    readonly property bool contentReady: active
        && opacity > 0.95
        && Math.abs(cardX) < 1

    default property alias contentData: contentHost.data

    z: active ? 1 : 0
    opacity: prewarm ? Math.max(0.001, transitionProgress) : transitionProgress
    enabled: contentReady
    clip: true

    // 退出与进入同时开始：交叉淡入淡出，不再先退出、空一拍再进入。
    function syncActivePage() {
        transitionProgress = active ? 1 : 0
    }

    onActiveChanged: syncActivePage()
    onReducedMotionChanged: syncActivePage()

    Behavior on transitionProgress {
        enabled: !root.reducedMotion

        NumberAnimation {
            duration: root.active
                ? Config.BarTuning.panelPageInDuration
                : Config.BarTuning.panelPageOutDuration
            easing.type: Easing.OutCubic
        }
    }

    Item {
        id: contentHost

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width
        x: root.inactiveX * (1 - root.transitionProgress)
        scale: root.inactiveScale
            + (1 - root.inactiveScale) * root.transitionProgress
        transformOrigin: Item.Center
    }
}
