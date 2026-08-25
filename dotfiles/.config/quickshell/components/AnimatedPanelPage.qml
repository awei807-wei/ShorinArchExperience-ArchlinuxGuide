import "../config" as Config
import QtQuick

// 常驻页面包装器：切页时只改变页面的透明度和水平位移，
// 不销毁/重建页面实例，也不重新播放外层面板的开合动画。
Item {
    id: root

    property bool active: false
    property bool reducedMotion: false
    // Control 从左侧退场，History 可将此值设为 12 从右侧退场。
    property real inactiveX: -12
    property real transitionOpacity: active ? 1 : 0

    readonly property bool contentVisible: transitionOpacity > 0.001
    readonly property bool contentReady: active && opacity > 0.95

    default property alias contentData: contentHost.data

    opacity: transitionOpacity
    visible: contentVisible
    enabled: contentReady

    function syncActivePage() {
        pageInDelay.stop()

        if (reducedMotion) {
            transitionOpacity = active ? 1 : 0
            return
        }

        if (active)
            pageInDelay.restart()
        else
            transitionOpacity = 0
    }

    onActiveChanged: syncActivePage()
    onReducedMotionChanged: syncActivePage()

    Timer {
        id: pageInDelay

        interval: Config.BarTuning.panelPageInDelay
        onTriggered: {
            if (root.active)
                root.transitionOpacity = 1
        }
    }

    Behavior on transitionOpacity {
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
        x: root.active ? 0 : root.inactiveX

        Behavior on x {
            enabled: !root.reducedMotion

            NumberAnimation {
                duration: Config.BarTuning.panelPageMoveDuration
                easing.type: Easing.OutCubic
            }
        }
    }
}
