// 统一悬浮提示（tooltip）：深色圆角小卡片，延迟 500ms 淡入。
// 用法（挂在 MouseArea / HoverHandler 所在项的兄弟节点）：
//   MouseArea { id: area; hoverEnabled: true }
//   AppToolTip { text: "Wi-Fi"; target: area }
// 也可以传任意 Item 并手动控制 hovered：
//   AppToolTip { text: "音量"; target: iconButton; hovered: iconButtonMouse.containsMouse }
import "../config" as Config
import QtQuick

Rectangle {
    id: root

    // 提示文本
    property string text: ""
    // 目标区域：传 MouseArea（或带 hovered 属性的 HoverHandler）时自动跟随其悬停状态
    property var target: null
    // 手动指定悬停态；默认读取 target.hovered（HoverHandler）或 target.containsMouse（MouseArea）
    property bool hovered: {
        if (!target)
            return false
        if (target.hovered !== undefined)
            return target.hovered
        if (target.containsMouse !== undefined)
            return target.containsMouse
        return false
    }
    // 目标组件需要保持交互/可用时才显示（如传入 enabled: root.interactive）
    property bool enabled: true
    // 延迟与动画时长
    property int delay: 500
    property int fadeDuration: Config.Theme.animFast

    readonly property bool active: enabled && text.length > 0 && hovered

    z: 100
    width: tipText.implicitWidth + Config.Theme.spacingSmall * 2
    height: tipText.implicitHeight + Config.Theme.spacingTiny * 2
    radius: Config.Theme.radiusSmall
    color: Config.Theme.surfaceContainer
    border.color: Config.Theme.outlineVariant
    border.width: 1
    visible: opacity > 0
    opacity: 0

    Behavior on opacity {
        NumberAnimation {
            duration: root.fadeDuration
            easing.type: Easing.OutQuad
        }
    }

    Text {
        id: tipText
        anchors.centerIn: parent
        text: root.text
        textFormat: Text.PlainText
        font.pixelSize: Config.Theme.fontTiny
        color: Config.Theme.textPrimary
    }

    // 延迟 500ms 后淡入；悬停结束立刻隐藏并复位延迟
    onActiveChanged: {
        if (active) {
            appearTimer.restart()
        } else {
            appearTimer.stop()
            opacity = 0
        }
    }

    Timer {
        id: appearTimer
        interval: root.delay
        onTriggered: root.opacity = 1
    }
}
