pragma Singleton

import QtQuick

// ═══════════════════════════════════════════════════════════════
// 🎨 Theme · 全局主题 token 单例（颜色 / 圆角 / 字号 / 间距 / 动画 / 阴影）
// ═══════════════════════════════════════════════════════════════
//
// 使用方法（与 BarTuning 相同的单例模式）：
//
//   1) 在任意 QML 文件顶部：
//          import "config" as Config        // 路径按所在目录调整
//      或（在 config/ 目录内的文件）：
//          import "." as Config
//
//   2) 引用 token：
//          color: Config.Theme.textPrimary
//          radius: Config.Theme.radiusMedium
//          font.pixelSize: Config.Theme.fontBody
//          spacing: Config.Theme.spacingSmall
//          Behavior on opacity { NumberAnimation { duration: Config.Theme.animFast } }
//
//   3) 已注册于 config/qmldir（singleton Theme 1.0 Theme.qml），
//      quickshell 会保证全局只有一个实例，改值即全局热更新。
//
// 动态配色：
//   shell.qml 的 applyDynamicColors() 监听 matugen 生成的
//   ~/.cache/matugen/colors.json，把 8 个字段映射到本单例的颜色 token
//   （带 300ms ColorAnimation 平滑过渡）。
//   matugen 文件缺失 / 字段缺失时，所有 token 回落到下方静态兜底值，
//   界面始终可以正常显示。
// ═══════════════════════════════════════════════════════════════
QtObject {
    // ═══════════════════════════════════════════════════════
    // 1. 颜色 token（静态兜底 = 现有 zen 色系，动态由 matugen 覆盖）
    // ═══════════════════════════════════════════════════════

    // 主背景色：Bar / 面板主体底色（matugen: surface）
    property color surface: "#101010"
    Behavior on surface { ColorAnimation { duration: animSlow } }

    // 悬停 / 提升底色：hover 时的背景提升（matugen: surface_container）
    property color surfaceContainer: "#1c1c1c"
    Behavior on surfaceContainer { ColorAnimation { duration: animSlow } }

    // 边框 / 分割线（matugen: outline_variant）
    property color outline: "#252525"
    Behavior on outline { ColorAnimation { duration: animSlow } }

    // 弱边框 / 低对比辅助线（静态兜底，matugen 无对应字段）
    property color outlineVariant: "#404040"
    Behavior on outlineVariant { ColorAnimation { duration: animSlow } }

    // 高对比文本：主要内容（matugen: on_surface）
    property color textPrimary: "#d0d0d0"
    Behavior on textPrimary { ColorAnimation { duration: animSlow } }

    // 中等文本：常规信息（matugen: outline；比原 #999 调亮以提升对比度）
    property color textSecondary: "#a8a8a8"
    Behavior on textSecondary { ColorAnimation { duration: animSlow } }

    // 弱文本：次要文字 / 图标（静态兜底；比原 #707070 调亮，满足 WCAG AA 4.5:1）
    property color textMuted: "#8a8a8a"
    Behavior on textMuted { ColorAnimation { duration: animSlow } }

    // 强调色：进度条 / 关键状态（matugen: primary）
    property color accent: "#5a9a8a"
    Behavior on accent { ColorAnimation { duration: animSlow } }

    // 次级强调色（matugen: secondary）
    property color accentSecondary: "#8a9a92"
    Behavior on accentSecondary { ColorAnimation { duration: animSlow } }

    // 三级强调色（matugen: tertiary）
    property color accentTertiary: "#a89898"
    Behavior on accentTertiary { ColorAnimation { duration: animSlow } }

    // 低饱和危险色：通知数字 / 清理动作（静态兜底，matugen 无对应语义色）
    property color danger: "#9a5555"
    Behavior on danger { ColorAnimation { duration: animSlow } }

    // 阴影颜色（带 alpha）
    property color shadowColor: "#00000088"
    Behavior on shadowColor { ColorAnimation { duration: animSlow } }

    // ═══════════════════════════════════════════════════════
    // 2. 圆角 token（px）
    // ═══════════════════════════════════════════════════════
    readonly property int radiusSmall: 8
    readonly property int radiusMedium: 12
    readonly property int radiusLarge: 16

    // ═══════════════════════════════════════════════════════
    // 3. 字号 token（px，不低于 9px）
    // ═══════════════════════════════════════════════════════
    readonly property int fontTiny: 9
    readonly property int fontSmall: 10
    readonly property int fontBody: 12
    readonly property int fontTitle: 14
    readonly property int fontLarge: 18

    // ═══════════════════════════════════════════════════════
    // 4. 间距 token（8px 网格）
    // ═══════════════════════════════════════════════════════
    readonly property int spacingTiny: 4
    readonly property int spacingSmall: 8
    readonly property int spacingMedium: 12
    readonly property int spacingLarge: 16

    // ═══════════════════════════════════════════════════════
    // 5. 动画时长 token（ms）
    // ═══════════════════════════════════════════════════════
    readonly property int animFast: 120
    readonly property int animNormal: 200
    readonly property int animSlow: 300
}
