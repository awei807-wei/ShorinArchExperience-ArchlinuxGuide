pragma Singleton

// Brain_Shell Theme shim — 把 Brain_Shell 的 token 映射到本配置的
// Config.Theme（matugen 动态配色），使 vendor 内移植代码零改动运行。
// 来源：Brain_Shell (MIT) https://github.com/Brainitech/Brain_Shell
import QtQuick
import "../../config" as Config

QtObject {
    // 主背景（Brain 用近黑，本配置 surface 同为深底，白字体系一致）
    readonly property color background: Config.Theme.surface
    // 主文本
    readonly property color text: Config.Theme.textPrimary
    // 强调色（matugen 动态）
    readonly property color active: Config.Theme.accent
    // 几何 token（Brain 原值，面板形状依赖）
    readonly property int cornerRadius: 17
    readonly property int notchRadius: 15
    readonly property int notchHeight: 40
    // 面板闭合态宽度兜底值（实际宽度由 CenterPanelController 提供）
    readonly property int cNotchMinWidth: 300
    // 面板展开后的固定高度（Brain 原值）
    readonly property int dashboardHeight: 520
    // 动画时长与 panelShellDuration 对齐
    readonly property int animDuration: 300
}
