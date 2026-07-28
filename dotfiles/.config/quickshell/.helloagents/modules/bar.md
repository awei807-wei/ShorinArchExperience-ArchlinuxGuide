# 模块: 桌面 Bar

## 用途
提供跨 niri、Hyprland、KDE/GNOME 与通用桌面会话的顶部状态栏，统一呈现上下文、时钟、系统指标、托盘和电源入口。

## 关键文件
- `Bar.qml`：三语义区装配、稳定视觉 token 与响应式宽度预算。
- `Niri.qml`：共享 niri workspace 数据、事件流与聚焦动作。
- `services/TopBarState.qml`：共享 CPU、MEM、NET、天气和 Cava 数据。
- `components/ContextIsland.qml`：桌面环境路由与 Context 内容契约。
- `components/ClockIsland.qml`：时间、日期、天气与轻量音量反馈。
- `components/SystemIsland.qml`：Metrics、Tray 与 Power 的右侧系统集群。
- `bar-layout-check.qml`：2048/1280/1024/800 宽度的几何与退让顺序门禁。

## 依赖
依赖 Quickshell 0.3、QtQuick、SystemTray；niri 使用 `niri msg`，Hyprland 使用可选 `Quickshell.Hyprland`，频谱使用 Cava，天气沿用 Waybar weather 脚本。

## 经验
- [2026-07-28] 多屏 Bar 的长驻采集必须放在单例中，视图只按 screen/output 过滤；否则每块屏幕都会重复启动事件流和频谱进程。
- [2026-07-28] QML 紧凑组件应避开内建 `state` 命名，并用显式 Loader 绑定与 `ComponentBehavior: Bound` 固化作用域，不能只以运行时可加载作为静态质量标准。
- [2026-07-28] 会写持久数据的状态检查必须注入独立临时路径；视觉/布局测试同时使用 `QUICKSHELL_TEST_MODE=1`，避免触发真实采集和用户数据链路。
