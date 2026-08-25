import "../config" as Config
import QtQuick

// 常驻页面包装器：把整页作为一张卡片做推拉、淡入和轻微缩放，
// 不销毁/重建页面实例，也不重新播放外层面板的开合动画。
Item {
    id: root

    property bool active: false
    property bool reducedMotion: false
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
    opacity: transitionProgress
    visible: contentVisible
    enabled: contentReady
    clip: true

    function syncActivePage() {
        pageInDelay.stop()

        if (reducedMotion) {
            transitionProgress = active ? 1 : 0
            return
        }

        if (active)
            pageInDelay.restart()
        else
            transitionProgress = 0
    }

    onActiveChanged: syncActivePage()
    onReducedMotionChanged: syncActivePage()

    Timer {
        id: pageInDelay

        interval: Config.BarTuning.panelPageInDelay
        onTriggered: {
            if (root.active)
                root.transitionProgress = 1
        }
    }

    Behavior on transitionProgress {
        enabled: !root.reducedMotion

        NumberAnimation {
            duration: root.active
                ? Config.BarTuning.panelPageInDuration
                : Config.BarTuning.panelPageOutDuration
            easing.type: root.active ? Easing.OutCubic : Easing.InQuad
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
