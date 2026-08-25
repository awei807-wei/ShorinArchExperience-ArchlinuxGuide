pragma Singleton

import QtQuick

// 顶栏像素微调入口
//
// 使用方法：只修改本文件中的数值并保存，Quickshell 会自动热重载。
// 除响应式阈值和透明度外，尺寸与位置数值均以 px 为单位。
// 建议每次只改 1–2px，并同时观察常用宽度和 660px 档是否仍然无重叠。
QtObject {
    // ═══════════════════════════════════════════════════════
    // 1. 顶栏整体位置与岛面外框
    // ═══════════════════════════════════════════════════════

    // 控制：所有岛内部内容区域的高度。
    property int islandHeight: 40
    // 控制：顶部连接带与岛体共同占用的顶栏窗口总高度。
    property int barHeight: 40
    // 控制：从屏幕顶边向下连续铺满的连接带厚度。
    property int barTopBorderWidth: 6
    // 控制：岛屿上部内凹与下部外凸圆角的共同半径。
    property int barNotchRadius: 15
    // 控制：相邻岛主体之间的最小间距，给两侧反 R 角各留出 15px。
    property int barExclusionGap: 34
    // 控制：内容在贴顶岛体内的垂直位置。
    property int islandContentTop: 0
    // 控制：岛内 hover 等局部反馈的圆角半径。
    property int islandRadius: 6
    // 控制：岛面外边框宽度。
    property int islandBorderWidth: 1
    // 控制：岛内顶部白色高光线高度。
    property int islandTopHighlightHeight: 1
    // 控制：三个主岛内容之间的基础交互安全间距。
    property int islandGap: 8
    // 控制：整条 Bar 距屏幕顶部的位置。
    property int barMarginTop: 0
    // 控制：左岛和右岛距屏幕左右边缘的位置。
    property int barMarginSide: 0
    // 控制：左岛水平偏移，正值向右、负值向左。
    property int leftIslandOffsetX: 0
    // 控制：中岛相对屏幕中心偏移，正值向右、负值向左。
    property int centerIslandOffsetX: 0
    // 控制：右岛水平偏移，正值向右、负值向左。
    property int rightIslandOffsetX: 0
    // 控制：左右屏幕侧边轨道宽度，与顶部连接带保持一致。
    readonly property int screenEdgeBorderWidth: barTopBorderWidth
    // 控制：左右岛底边融入屏幕侧边轨道的内凹半径。
    property int screenEdgeCornerRadius: 17

    // ═══════════════════════════════════════════════════════
    // 2. 右岛双页子面板（Brain_Shell 展开几何）
    // ═══════════════════════════════════════════════════════

    // 右侧 Control/History 面板的统一逻辑像素 token。这里的数值直接
    // 用于 QML 布局，不随显示器缩放比例再次换算；旧 rightPanel* token
    // 保留在下方，供尚未迁移的入口兼容使用。
    property int rightPanelWidthMin: 560
    property int rightPanelWidthMax: 640
    property real rightPanelWidthRatio: 0.31

    // Control / History 共用同一高度，翻页期间外壳几何保持不变。
    property int rightPanelHeight: 760

    property int rightPanelNeckWidth: 304
    property int rightPanelRadius: 18
    property int rightPanelFlare: 16

    // 关闭态右岛只承载压缩状态、一个直接 Tray 项、复合入口与电源。
    // 最坏宽度为 130 + 8 + 60 + 4 + 38 = 240px。
    property int rightIslandMetricsWidth: 130
    property int rightIslandDirectIconLimit: 1

    property int rightPanelPaddingH: 24
    property int rightPanelPaddingTop: 18
    property int rightPanelGap: 14
    property int rightPanelControlGap: 12

    property int rightPanelFooterHeight: 58
    property int rightPanelTabsWidth: 296
    property int rightPanelTabsHeight: 38

    property int notificationCardMinHeight: 88
    property int notificationCardGap: 10
    property int notificationCardRadius: 14

    property int rightPanelControlHeaderHeight: 84
    property int rightPanelControlToggleHeight: 100
    property int rightPanelControlSliderHeight: 86
    property int rightPanelControlStatsHeight: 118
    property int rightPanelControlMediaHeight: 116
    property int rightPanelQuickIconSize: 54
    property int rightPanelSliderTrackHeight: 10
    property int rightPanelSliderHandleSize: 28

    // 打开/关闭分阶段时序（ms）。阶段之间的错位让面板先建立颈部，
    // 再横向、纵向展开，最后才显示页面内容。
    property int panelNotchOpenDuration: 140
    property int panelWidthOpenDelay: 40
    property int panelWidthOpenDuration: 170
    property int panelHeightOpenDelay: 95
    property int panelHeightOpenDuration: 240
    property int panelContentInDelay: 180
    property int panelContentInDuration: 150

    property int panelContentOutDuration: 80
    property int panelHeightCloseDelay: 20
    property int panelHeightCloseDuration: 180
    property int panelWidthCloseDelay: 70
    property int panelWidthCloseDuration: 150
    property int panelNotchCloseDelay: 120
    property int panelNotchCloseDuration: 130

    // 页面切换时保留两个页面实例，以整页卡片做推拉、淡入和轻微缩放。
    property int panelPageOutDuration: 90
    property int panelPageInDelay: 40
    property int panelPageInDuration: 150
    property int panelPageCardOffset: 28
    property real panelPageCardInactiveScale: 0.985
    property int panelTabIndicatorDuration: 190

    // ═══════════════════════════════════════════════════════
    // 3. 响应式切换阈值（屏幕宽度 px）
    // ═══════════════════════════════════════════════════════

    // 控制：达到此宽度后显示 Tray 直接图标。
    property int fullTrayMinWidth: 1273
    // 控制：达到此宽度后保留 Tray 表面；更窄时只保留 Power。
    property int traySurfaceMinWidth: 1008
    // 控制：达到此宽度后使用紧凑档；更窄进入超紧凑档。
    property int compactMinWidth: 760
    // 控制：布局测试覆盖的最小支持宽度。
    property int minimumSupportedWidth: 660

    // ═══════════════════════════════════════════════════════
    // 4. 左侧 Context Island
    // ═══════════════════════════════════════════════════════

    // 控制：Context 常规宽度（宽屏、标准屏和 1024px 档）。
    property int contextWidth: 200
    // 控制：Context 在 760–979px 档的宽度。
    property int contextCompactWidth: 184
    // 控制：Context 在 <760px 档的宽度。
    property int contextUltraWidth: 172
    // 控制：常规档顶部冰蓝短线距左边缘的位置。
    property int contextAccentX: 12
    // 控制：紧凑档顶部冰蓝短线距左边缘的位置。
    property int contextAccentCompactX: 9
    // 控制：常规档顶部冰蓝短线宽度。
    property int contextAccentWidth: 20
    // 控制：紧凑档顶部冰蓝短线宽度。
    property int contextAccentCompactWidth: 16
    // 控制：Context 冰蓝短线透明度。
    property real contextAccentOpacity: 0.9

    // 控制：RANGE 与工作区区域的常规左右内边距。
    property int contextHorizontalPadding: 9
    // 控制：RANGE 与工作区区域的紧凑左右内边距。
    property int contextCompactHorizontalPadding: 7
    // 控制：RANGE、分隔线、工作区之间的常规水平间距。
    property int contextContentGap: 6
    // 控制：RANGE、分隔线、工作区之间的紧凑水平间距。
    property int contextCompactContentGap: 5
    // 控制：RANGE / 01–05 / WS 01 信息列宽度。
    property int contextMetaWidth: 46
    // 控制：紧凑档信息列宽度。
    property int contextCompactMetaWidth: 42
    // 控制：RANGE 三行文字的垂直间距。
    property int contextMetaSpacing: 1
    // 控制：RANGE/HYPR 标签字号。
    property int contextLabelFontSize: 7
    // 控制：01–05 或 WS 04 主值字号。
    property int contextValueFontSize: 9
    // 控制：WS 01 / OCC 状态字号。
    property int contextStatusFontSize: 7
    // 控制：信息列和工作区之间的竖分隔线高度。
    property int contextDividerHeight: 18

    // 控制：五个工作区槽位之间的常规间距。
    property int workspaceGap: 3
    // 控制：五个工作区槽位之间的紧凑间距。
    property int workspaceCompactGap: 2
    // 控制：工作区编号字号。
    property int workspaceNumberFontSize: 10
    // 控制：工作区编号距岛顶部的位置。
    property int workspaceNumberTop: 12
    // 控制：工作区底部短线高度。
    property int workspaceIndicatorHeight: 3
    // 控制：工作区短线距岛底部的位置。
    property int workspaceIndicatorBottom: 6
    // 控制：当前工作区短线的常规宽度。
    property int workspaceActiveWidth: 30
    // 控制：当前工作区短线的紧凑宽度。
    property int workspaceCompactActiveWidth: 24
    // 控制：非当前工作区短线的常规宽度。
    property int workspaceInactiveWidth: 10
    // 控制：非当前工作区短线的紧凑宽度。
    property int workspaceCompactInactiveWidth: 12
    // 控制：键盘焦点顶部短线宽度。
    property int workspaceFocusWidth: 0
    // 控制：键盘焦点短线距岛顶部的位置。
    property int workspaceFocusTop: 3

    // 控制：Desktop/Fallback 模式常规左右内边距。
    property int desktopContextPadding: 11
    // 控制：Desktop/Fallback 模式紧凑左右内边距。
    property int desktopContextCompactPadding: 8
    // 控制：Desktop/Fallback 两列之间的常规间距。
    property int desktopContextGap: 10
    // 控制：Desktop/Fallback 两列之间的紧凑间距。
    property int desktopContextCompactGap: 8
    // 控制：Desktop/Fallback 左侧信息列常规宽度。
    property int desktopContextMetaWidth: 78
    // 控制：Desktop/Fallback 左侧信息列紧凑宽度。
    property int desktopContextCompactMetaWidth: 68
    // 控制：Desktop/Fallback 主值字号。
    property int desktopPrimaryFontSize: 8
    // 控制：Desktop/Fallback 标签与弱状态字号。
    property int desktopSecondaryFontSize: 6
    // 控制：Desktop/Fallback 右侧状态字号。
    property int desktopContextFontSize: 7

    // ═══════════════════════════════════════════════════════
    // 5. 中央 Clock Island
    // ═══════════════════════════════════════════════════════

    // 控制：中岛常规宽度。
    property int clockWidth: 240
    // 控制：中岛在 760–979px 档的宽度。
    property int clockCompactWidth: 176
    // 控制：中岛在 <760px 档的宽度。
    property int clockUltraWidth: 160
    // 控制：常规档时间列宽度。
    property int clockTimeColumnWidth: 80
    // 控制：紧凑档时间列宽度。
    property int clockCompactTimeColumnWidth: 72
    // 控制：超紧凑档时间列宽度。
    property int clockUltraTimeColumnWidth: 64
    // 控制：常规档日期列宽度。
    property int clockDateColumnWidth: 102
    // 控制：紧凑档日期列宽度。
    property int clockCompactDateColumnWidth: 94
    // 控制：超紧凑档日期列宽度。
    property int clockUltraDateColumnWidth: 82
    // 控制：主时间字号。
    property int clockTimeFontSize: 18
    // 控制：日期字号。
    property int clockDateFontSize: 7
    // 控制：星期和音量反馈字号。
    property int clockWeekdayFontSize: 6
    // 控制：日期列内容距左侧分隔线的常规位置。
    property int clockDateInset: 11
    // 控制：日期列内容距左侧分隔线的紧凑位置。
    property int clockCompactDateInset: 8
    // 控制：日期与星期之间的垂直间距。
    property int clockMetaSpacing: 4
    // 控制：中岛竖分隔线高度。
    property int clockDividerHeight: 18
    // 控制：时间数字字距。
    property real clockTimeLetterSpacing: -0.65

    // ═══════════════════════════════════════════════════════
    // 6. 右侧控制中心标题栏
    // ═══════════════════════════════════════════════════════

    // 控制：时间右侧天气文本区域宽度。
    property int controlCenterWeatherWidth: 44
    // 控制：时间与天气之间竖分隔线高度。
    property int controlCenterWeatherDividerHeight: 28
    // 控制：右侧控制中心天气字号；保留旧名称以兼容现有手动配置。
    property int clockWeatherFontSize: 12

    // ═══════════════════════════════════════════════════════
    // 7. 右侧 Metrics 与频谱
    // ═══════════════════════════════════════════════════════

    // 控制：Metrics 常规宽度。
    property int metricsWidth: 288
    // 控制：Metrics 在 760–979px 档的宽度。
    property int metricsCompactWidth: 220
    // 控制：Metrics 在 <760px 档的宽度。
    property int metricsUltraWidth: 176
    // 控制：Metrics 与 Tray/Power 工具组之间的距离。
    property int metricsUtilityGap: 8
    // 控制：Metrics 小于此宽度时启用紧凑内排版。
    property int metricsCompactLayoutThreshold: 270
    // 控制：Metrics 小于此宽度时使用更小字号。
    property int metricsSmallFontThreshold: 180
    // 控制：Metrics 常规左右内边距。
    property int metricsOuterPadding: 8
    // 控制：Metrics 紧凑左右内边距。
    property int metricsCompactOuterPadding: 6
    // 控制：Metrics 常规标签和值字号。
    property int metricsFontSize: 7
    // 控制：Metrics 超紧凑字号。
    property int metricsSmallFontSize: 6
    // 控制：Metrics 顶部冰蓝短线 X 位置。
    property int metricsAccentX: 12
    // 控制：Metrics 顶部冰蓝短线宽度。
    property int metricsAccentWidth: 20
    // 控制：Metrics 顶部冰蓝短线透明度。
    property real metricsAccentOpacity: 0.9
    // 控制：四项指标竖分隔线的顶部位置。
    property int metricsDividerY: 10
    // 控制：四项指标竖分隔线高度。
    property int metricsDividerHeight: 17
    // 控制：显示分段仪表时文字的常规 Y 位置。
    property int metricsTextY: 8
    // 控制：显示分段仪表时文字的紧凑 Y 位置。
    property int metricsCompactTextY: 9
    // 控制：隐藏分段仪表时文字的常规 Y 位置。
    property int metricsTextYWithoutSegments: 14
    // 控制：隐藏分段仪表时文字的紧凑 Y 位置。
    property int metricsCompactTextYWithoutSegments: 15
    // 控制：显示分段仪表时单格常规左右内边距。
    property int metricsCellPadding: 6
    // 控制：显示分段仪表时单格紧凑左右内边距。
    property int metricsCompactCellPadding: 4
    // 控制：隐藏分段仪表时单格常规左右内边距。
    property int metricsCellPaddingWithoutSegments: 5
    // 控制：隐藏分段仪表时单格紧凑左右内边距。
    property int metricsCompactCellPaddingWithoutSegments: 3
    // 控制：分段仪表距 Metrics 顶部的位置。
    property int metricsSegmentY: 26
    // 控制：每项指标的分段数量。
    property int metricsSegmentCount: 8
    // 控制：分段仪表高度。
    property int metricsSegmentHeight: 2
    // 控制：分段之间的间距。
    property int metricsSegmentGap: 2
    // 控制：单格中标签占比。
    property real metricsLabelWidthRatio: 0.38
    // 控制：单格中数值占比。
    property real metricsValueWidthRatio: 0.57

    // 控制：频谱背景距 Metrics 顶部的位置。
    property int spectrumTopInset: 7
    // 控制：频谱背景距 Metrics 底部的位置。
    property int spectrumBottomInset: 4
    // 控制：频谱柱数量。
    property int spectrumBarCount: 32
    // 控制：频谱柱之间的间距。
    property int spectrumBarGap: 2
    // 控制：最低频谱柱高度。
    property int spectrumMinBarHeight: 6
    // 控制：频谱柱从最低到最高额外增加的高度。
    property int spectrumBarHeightRange: 16
    // 控制：有音频时整个频谱层透明度。
    property real spectrumActiveOpacity: 0.62
    // 控制：无音频时整个频谱层透明度。
    property real spectrumInactiveOpacity: 0.06
    // 控制：有音频时单柱透明度。
    property real spectrumActiveBarOpacity: 0.34
    // 控制：无音频时单柱透明度。
    property real spectrumInactiveBarOpacity: 0.20

    // ═══════════════════════════════════════════════════════
    // 8. Tray 与 Power
    // ═══════════════════════════════════════════════════════

    // 控制：Tray 与 Power 两个表面之间的距离。
    property int trayPowerGap: 4
    // 控制：Tray 展开宽度的基础单位。
    property int trayUnit: 8
    // 控制：每个 Tray 图标槽位的宽高。
    property int trayItemWidth: 18
    // 控制：Tray 应用图标实际宽高；16 表示不缩小。
    property int trayIconSize: 18
    // 控制：Tray 图标槽位之间的间距。
    property int trayItemGap: 4
    // 控制：Tray 左右内边距总和。
    property int trayHorizontalPadding: 20
    // 控制：Tray 展开最小宽度的单位倍数。
    property int trayExpandedMinUnits: 18
    // 控制：“+2”复合入口字号。
    property int trayCompositeFontSize: 10
    // 控制：通知角标相对槽位顶部的位置。
    property int trayBadgeTopOffset: -4
    // 控制：通知角标相对槽位右侧的位置。
    property int trayBadgeRightOffset: -5
    // 控制：通知角标高度。
    property int trayBadgeHeight: 10
    // 控制：通知角标数字字号。
    property int trayBadgeFontSize: 5
    // 控制：展开态收起符号字号。
    property int trayCollapseFontSize: 9
    // 控制：空 Tray 的省略符字号。
    property int trayEmptyFontSize: 6
    // 控制：Power 岛宽度。
    property int powerIslandWidth: 38
    // 控制：Power 细线图标宽高。
    property int powerGlyphSize: 14
    // 控制：Power 图标线宽。
    property real powerGlyphStrokeWidth: 1.25
    // 控制：Power 键盘焦点框距边缘的位置。
    property int powerFocusInset: 3

    // 以下宽度由上面的槽位参数自动计算，一般不需要修改。
    readonly property int trayMinimumWidth: trayItemWidth + trayHorizontalPadding
    readonly property int trayCompositeWidth: trayMinimumWidth
    readonly property int trayMaximumCollapsedWidth: 4 * trayItemWidth
        + 3 * trayItemGap + trayHorizontalPadding
    readonly property int trayExpandedMinWidth: trayUnit * trayExpandedMinUnits
    // 宽屏布局以最坏情况（3 个软件图标 + 复合入口）预留防重叠预算；
    // Tray 实际宽度仍由当前项目数动态决定。
    readonly property int systemWideWidth: metricsWidth + metricsUtilityGap
        + trayMaximumCollapsedWidth + trayPowerGap + powerIslandWidth
    readonly property int systemCollapsedTrayWidth: metricsWidth + metricsUtilityGap
        + trayCompositeWidth + trayPowerGap + powerIslandWidth
    readonly property int systemCompactWidth: metricsCompactWidth
        + metricsUtilityGap + powerIslandWidth
    readonly property int systemUltraWidth: metricsUltraWidth
        + metricsUtilityGap + powerIslandWidth
}
