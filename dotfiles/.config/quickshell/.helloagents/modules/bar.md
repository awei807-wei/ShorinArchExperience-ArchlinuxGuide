# 模块: 桌面 Bar

## 用途
提供跨 niri、Hyprland、KDE/GNOME 与通用桌面会话的顶部状态栏，统一呈现上下文、时钟、系统指标、托盘和电源入口。

## 关键文件
- `config/BarTuning.qml`：唯一像素微调入口，集中管理三岛位置、宽度、字号、内部间距与响应式阈值。
- `Bar.qml`：三语义区装配、稳定视觉 token 与响应式宽度预算。
- `Niri.qml`：共享 niri workspace 数据、事件流与聚焦动作。
- `services/TopBarState.qml`：共享 CPU、MEM、NET、天气和 Cava 数据。
- `components/ImportedControlCenterPanel.qml`：右岛当前调用的唯一控制中心，在标题栏显示时间、日期与天气，并提供网络、蓝牙、音量、亮度、系统占用和媒体控制。
- `components/ContextIsland.qml`：桌面环境路由与 Context 内容契约。
- `components/ClockIsland.qml`：时间、日期与轻量音量反馈；不再占用顶栏宽度显示天气。
- `components/SystemIsland.qml`：Metrics、Tray 与 Power 的右侧系统集群。
- `components/TrayIsland.qml`：消费持久通知历史来源计数，稳定排序托盘应用，维护动态槽位、复合入口和总数角标，并通过单个进程调用托盘窗口聚焦脚本。
- `components/TrayItem.qml`：单个托盘图标的 hover、右键菜单、键盘焦点、单击/双击消歧、激活行为与每应用通知角标。
- `components/TrayNotificationModel.js`：规范化 Desktop Entry/应用名，执行唯一匹配、受限 QQ 归属与稳定排序。
- `scripts/focus-tray-item.sh`：按托盘 `id/title/tooltipTitle` 对 niri 窗口进行确定性评分和最近聚焦；通知卡片继续使用 `focus-notification-source.sh`。回归 fixture 位于 `scripts/test-focus-tray-item.sh`。
- `bar-layout-check.qml`：2048/1280/1024/980/979/800/660 宽度的几何、阈值与退让顺序门禁。
- `tray-interaction-check.qml`：单击延迟激活、双击取消激活并聚焦、右键取消待执行单击的交互回归。
- `tests/EdgeIntegratedBar.qml`、`tests/edge-integrated-preview.qml`、`tests/shell.qml`、`tests/edge-integrated-layout-check.qml`：与生产 Bar 完全隔离的 Edge-Integrated Contoured Bar 视觉原型、固定 mock 预览与 2048/1600/1280/800 布局门禁，呈现左/中/右三功能区，右侧含 Metrics/Tray/Power 三个相邻下伸子舱；`tests/shell.qml` 是目录启动入口，指向预览文件；仅用于测试和设计验证，不是现行生产视觉契约。

## 依赖
依赖 Quickshell 0.3、QtQuick、SystemTray；niri 使用 `niri msg`，Hyprland 使用可选 `Quickshell.Hyprland`，频谱使用 Cava，天气沿用 Waybar weather 脚本。

## 经验
- [2026-07-28] 多屏 Bar 的长驻采集必须放在单例中，视图只按 screen/output 过滤；否则每块屏幕都会重复启动事件流和频谱进程。
- [2026-07-28] QML 紧凑组件应避开内建 `state` 命名，并用显式 Loader 绑定与 `ComponentBehavior: Bound` 固化作用域，不能只以运行时可加载作为静态质量标准。
- [2026-07-28] 会写持久数据的状态检查必须注入独立临时路径；视觉/布局测试同时使用 `QUICKSHELL_TEST_MODE=1`，避免触发真实采集和用户数据链路。
- [2026-07-28] 紧凑 Bar 应同时调整外框宽度、内部列宽、字体和溢出约束；只压缩 `implicitWidth` 会导致 Workspace 标记、指标值或 Tray 槽位越界。Tray 与 Power 保持独立表面，但可用 `4px` 二级间距形成统一工具组。
- [2026-07-28] 位置与尺寸常量必须集中在 `config/BarTuning.qml`；组件和测试共同消费该配置，避免手动微调后出现实现、响应式门禁与文档三处数值漂移。
- [2026-07-30] 中岛只承担时间与音量反馈，不再创建点击子面板；右岛仅保留当前控制中心，删除被替代的旧面板实现与无用采集链路。
- [2026-08-08] 托盘折叠宽度按实际应用数收缩，溢出仅占用复合入口；持久历史来源按 `desktopEntry`、`appName` 两阶段唯一匹配，计数降序且同数保持注册顺序，清空后实时恢复原序；临时通知分组不参与角标。
- [2026-08-08] `TrayItem` 的身份字段延迟更新通过显式 revision 触发重排；测试夹具使用 `values` 数组对象模型，避免在 Qt 6.11 下直接创建 `ObjectModel`。
- [2026-08-08] `TrayItem` 左键单击延迟消歧，双击调用独立托盘聚焦脚本，避免破坏通知卡片既有聚焦语义。
- [2026-08-08] 托盘来源计数恢复为持久历史裁剪池；`append/count/list/clear` 均返回并更新 `sourceCounts`，QQ 仅匹配唯一空标签 `chrome_status_icon_1`，VCP tooltip 非空时不会串号。
- [2026-08-08] 自动门禁通过：Python 通知历史、offscreen 托盘/存储/布局检查、托盘聚焦 fixture、锁屏 `qmllint` 与 `git diff --check`；真实托盘与锁屏认证仍需人工验收。
- [2026-08-09] `tests/` Edge-Integrated Contoured Bar 原型使用固定 mock 呈现左/中/右三功能区，右侧含 Metrics/Tray/Power 三个相邻下伸子舱，并以 2048/1600/1280/800 布局门禁验证边界和内容安全区；它与生产 Bar 隔离，不应被视为现行生产视觉契约。
