# Quickshell 工业工作站顶栏 — 需求

确认后冻结，执行阶段不可修改。如需变更必须回到设计阶段重新确认。

## 核心目标
将现有 niri 专用顶栏重构为跨 niri、Hyprland、KDE Plasma、GNOME 与通用桌面会话的现代状态栏；保持 Context / Clock / System 三个语义区域，并准确落实 `preview.html` 的 Swiss editorial、工业仪表与精密工作站视觉。

## 功能边界
- 顶栏可见岛面固定为 38px 高，左右与顶部采用 4px 光学校准，顶级间距为 8px。
- 左侧 Context 根据桌面环境加载 Niri、Hyprland、Desktop 或 Fallback 视图。
- Niri 始终显示当前 5-slot 分页范围；Hyprland 显示附近 5 个工作区并区分 active、occupied、empty。
- Clock 始终保留时间与日期；天气是最低优先级，可在窄屏或音量反馈时退让。
- System 显示 NET / MEM / CPU / VOL，频谱只作为低透明度背景暗纹；托盘和 Power 保留独立表面。
- 响应式降级顺序固定为 Weather → Tray 直接图标 → Secondary metric detail，不隐藏 Context、Clock 和四项主指标值。

## 非目标
- 不重做 CenterPanel、SystemPanel、通知历史面板或锁屏。
- 不复制 `preview.html` 的连续 rail、可见网格、toast 或整体缩放调试能力。
- 不引入 Web 框架、强样式组件库、发光边框、RGB、玻璃拟态或大圆角。

## 技术约束
- 使用 Quickshell 0.3 / QtQuick 现有能力和现有 SystemTray、通知历史、wlogout 链路。
- niri 与系统指标采集必须为共享单例，避免多屏重复启动事件流、天气和 Cava 进程。
- Hyprland 视图隔离在独立 Loader 文件中，使用可选 `Quickshell.Hyprland` 模块，不影响其他桌面环境加载。
- 不修改用户提供的 `preview.html`；其视觉值仅作为参考，文字硬要求优先。

## 质量要求
- 新增 QML 文件通过 `qmlformat -n` 语法检查。
- 运行现有 tray 状态检查与新增 Bar 响应式布局检查。
- 在真实 niri 会话完成 Quickshell 加载烟测、日志审查与顶栏截图视觉验收。
- 颜色、尺寸、层级、状态和隐藏顺序与方案一致；无绑定环、重复采集进程或静默错误吞噬。
