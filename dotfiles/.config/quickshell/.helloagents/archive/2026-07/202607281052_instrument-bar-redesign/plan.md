# Quickshell 工业工作站顶栏 — 实施规划

## 目标与范围
替换当前 `LeftIsland / CenterIsland / RightIslands` 视图树，建立 Context / Clock / System 三个顶层语义组件；保留已有面板、托盘菜单、通知历史和电源行为，并让宽屏、普通屏与窄屏在固定 38px 高度下无重叠。

## 架构与实现策略
- `Niri.qml` 升级为唯一 niri workspace provider，保存真实 workspace 对象、按输出选择 active workspace、事件流重连并负责聚焦动作。
- 新增 `TopBarState` 单例集中 CPU、MEM、NET、天气与限帧后的 Cava 数据，所有屏幕共享一套采集进程。
- `ContextIsland` 只做环境路由与统一表面，四种 Context 组件只负责各自内容和交互。
- `ClockIsland` 始终显示时间；沿用现有 `centerIsland` 对外接口，但音量反馈仅替换低优先级辅助行，不再遮蔽时钟。
- `SystemIsland` 作为右侧语义集群，内部组合 `Metrics + TrayIsland + Power`；`Spectrum` 位于 Metrics 背景层。
- `Bar` 使用稳定宽度预算选择 5 个响应式等级，避免由 `implicitWidth` 反推显隐造成绑定振荡。

## 领域语言
- Context Island：随桌面环境切换的左侧上下文区域，不等同于固定 Workspace Bar。
- Primary metric：NET / MEM / CPU / VOL 的标签和值，任何受支持宽度都保留。
- Secondary metric detail：8 段仪表与额外视觉细节，可在窄屏隐藏。
- System cluster：右侧语义区域，包含 Metrics、Tray 和独立 Power 表面。

## 完成定义
- `Bar.qml` 只实例化 `ContextIsland`、`ClockIsland`、`SystemIsland` 三个顶层组件。
- 宽屏几何匹配参考稿：Context 238、Clock 300、Metrics 338、Tray 118、Power 38、间距 8、高度 38。
- 1280 / 1024 / 800 宽度按既定优先级降级且三个语义区域不相交。
- niri 当前工作区、分页范围和点击切换工作；Hyprland 组件可被独立解析且使用原生 service；Desktop/Fallback 不伪造 workspace。
- NET / MEM / CPU / VOL 有真实数据链路，频谱为中性灰低透明背景，Power 使用线稿图形。
- `qaMode=deep`；重点审查 QML 加载、响应式碰撞、多屏共享采集、托盘回归和真实截图。

## 文件结构
- 修改：`shell.qml`、`Bar.qml`、`Niri.qml`、`qmldir`、`components/TrayIsland.qml`、`components/NotificationHistoryStore.qml`、`notification-store-check.qml`、`scripts/cava.sh`、`.helloagents/DESIGN.md`。
- 新增：`services/TopBarState.qml`、`components/ContextContent.qml`、`components/ContextIsland.qml`、`components/NiriContext.qml`、`components/HyprlandContext.qml`、`components/DesktopContext.qml`、`components/FallbackContext.qml`、`components/WorkspaceStrip.qml`、`components/ClockIsland.qml`、`components/SystemIsland.qml`、`components/Metrics.qml`、`components/Spectrum.qml`、`components/Power.qml`、`bar-layout-check.qml`。
- 退役：`components/LeftIsland.qml`、`components/CenterIsland.qml`、`components/RightIslands.qml`。

## UI / 设计约束
- 设计方向：Swiss grid 的精确排版秩序 + 工业音频设备的状态层级，不做赛博朋克或游戏 HUD。
- 记忆点：每个主表面顶部的一条 1px 冰蓝校准标记；频谱只作为低透明背景纹理。
- 表面：主岛 `rgba(10,12,13,.94)`，次岛与工具岛不低于 .85；边框白色 8.5%，顶部内高光白色 4.5%，圆角 3px。
- 文字：`#E7E9EA / #A7ABAD / #6D7376`；仪表数字使用 JetBrains Mono，唯一常规强调色 `#8FB3C5`。
- 动效：只保留 120–180ms 状态过渡；无发光、缩放、抬升；`QUICKSHELL_REDUCE_MOTION=1` 时冻结频谱并关闭 Behavior。
- `.helloagents/DESIGN.md` 更新为稳定的 Swiss industrial Bar 契约，既有通知面板特有约束继续保留。

## 风险与验证
- 可选 Hyprland import 仅在对应 Loader 文件解析；通过 `qmlformat` 与本地 qmltypes 校验 API。
- Quickshell 多屏重复采集通过单例进程数量检查规避。
- 顶栏 PanelWindow 与岛面均固定为 38px，并采用 top/side 4px 边距；详情面板继续沿用既有独立尺度。
- 实际截图若出现 3D 浮起感，优先降低阴影；若发生碰撞，回退到更紧凑响应式等级而非缩放字体和高度。

## 决策记录
- [2026-07-28] 用户文字硬要求优先于 `preview.html` 的整体缩放、发光与低于 85% 的工具岛透明度。
- [2026-07-28] 保留四项主指标值，响应式第三阶段仅移除分段仪表和额外宽度，避免自行猜测哪一项可隐藏。
- [2026-07-28] 复用现有托盘通知复合入口，防止视觉重构破坏既有通知历史行为。
- [2026-07-28] 将 1280px 等级限定为仅隐藏 Weather，Tray 直接图标在 `<1273px` 后才退让，确保严格遵守响应式优先级。
- [2026-07-28] 为布局测试增加 `QUICKSHELL_TEST_MODE`，并为通知存储检查注入独立临时路径，隔离真实进程与持久数据。
