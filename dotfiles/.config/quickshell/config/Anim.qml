pragma Singleton

import QtQuick
import "." as Config
import ".." as Root

// 全局动画物理曲线与缓动系统单例 (Motion & Physics Curves Engine)
// 统一管理整套 UI 的开合动力学、物理回弹曲线参数以及时长标尺。
QtObject {
    id: root

    // 默认运动曲线风格："smooth" (流体优雅 OutCubic，桌面大面板最佳体感)
    // 可选："smooth" | "spring" (OutBack 微弹) | "snappy" (OutQuad 快速响应) | "cinematic" (InOutQuart)
    property string curveStyle: "smooth"

    // 速度倍率：1.0 为标准速度，数值越大越快
    property real speedMultiplier: 1.0

    // 是否减弱动画
    readonly property bool reducedMotion: Root.TopBarState.reducedMotion

    // ═══════════════════════════════════════════════════════════════
    // 1. 物理缓动曲线与参数映射
    // ═══════════════════════════════════════════════════════════════
    readonly property int globalCurve: {
        if (curveStyle === "spring") return Easing.OutBack
        if (curveStyle === "snappy") return Easing.OutQuad
        if (curveStyle === "cinematic") return Easing.InOutQuart
        if (curveStyle === "linear") return Easing.Linear
        return Easing.OutCubic // "smooth" 默认为柔和且带足够起步与减速过渡的 OutCubic
    }

    // 回弹过冲量：OutBack 调谐
    readonly property real globalOvershoot: {
        if (curveStyle === "spring") return 1.10
        return 1.70158
    }

    readonly property real globalAmplitude: 1.0
    readonly property real globalPeriod: 0.35

    // ═══════════════════════════════════════════════════════════════
    // 2. 时长标尺（根据 speedMultiplier 动态折算）
    // ═══════════════════════════════════════════════════════════════
    function scaleDuration(ms) {
        if (reducedMotion) return 0
        const mult = Math.max(0.1, speedMultiplier)
        return Math.max(1, Math.round(ms / mult))
    }

    readonly property int superFast: scaleDuration(80)
    readonly property int fast: scaleDuration(100)
    readonly property int color: scaleDuration(120)
    readonly property int mediumFast: scaleDuration(150)
    readonly property int normal: scaleDuration(200)
    readonly property int mediumSlow: scaleDuration(250)
    readonly property int slow: scaleDuration(300)
    readonly property int transition: scaleDuration(Math.max(320, Config.BarTuning.panelShellDuration))

    // 大尺寸面板展开主控曲线（保证 700px 高度展开具有舒展的运动过程感，绝不闪跳突变）
    readonly property int panelCurve: (curveStyle === "linear") ? Easing.Linear : Easing.OutCubic
    readonly property real panelOvershoot: (curveStyle === "spring") ? 1.08 : 1.70158
}