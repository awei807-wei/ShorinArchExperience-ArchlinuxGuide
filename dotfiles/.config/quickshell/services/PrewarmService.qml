pragma Singleton

import QtQuick
import "../config" as Config
import "." as Services

// 全局 Shader 与图元预热总线 (Global Prewarm Bus)
// 职责：
// 1. 在 Quickshell 启动或热重载后的前 1500ms（BarTuning.panelPrewarmDuration）内，
//    以人眼不可见的 0.001 下限透明度强制挂载各常驻面板的场景图；
// 2. 提前让 GPU 完成着色器编译（Shader Compilation）、矢量曲线抗锯齿管线构建与
//    字形纹理光栅化，将首次展开造成的 70~120ms 丢帧彻底消化在启动静默期；
// 3. 预热期结束后自动转为常规不可见（opacity: 0），不消耗多余的像素混合与合成带宽；
// 4. 提供统一的状态契约供 Dashboard、RightPanel 与 PowerMenu 共同消费。
QtObject {
    id: root

    // 预热是否处于活动状态
    property bool active: !Services.TopBarState.testMode
        && Config.BarTuning.panelPrewarmDuration > 0

    // 场景图保留下限透明度：Qt Quick 场景图中，低于 0.001 的子树会被直接剪枝，
    // 因此预热必须锁定在 0.001 才能确保管线真正建立。
    readonly property real opacityFloor: 0.001

    readonly property int duration: Config.BarTuning.panelPrewarmDuration

    signal prewarmCompleted()

    function complete() {
        if (!active) return
        active = false
        prewarmCompleted()
    }

    property var _timer: Timer {
        interval: Math.max(1, root.duration)
        running: root.active
        repeat: false
        onTriggered: {
            root.active = false
            root.prewarmCompleted()
        }
    }
}