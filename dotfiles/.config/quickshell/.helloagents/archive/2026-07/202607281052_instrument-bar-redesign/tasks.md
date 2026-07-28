# Quickshell 工业工作站顶栏 — 任务分解

## 拆分原则
- 默认按端到端垂直切片拆分：每个任务交付一个可验证行为，而不是单独交付某一层。
- `AFK` 表示代理可独立完成；`HITL` 表示需要用户决策、外部凭据、人工视觉确认或手动验收。
- 厚任务必须继续拆小；横向前置任务只在确有技术依赖时保留。

## 任务列表
- [√] 任务1（AFK）：建立共享 Bar 数据层与环境检测（依赖：无；涉及文件：`Niri.qml`、`services/TopBarState.qml`、`qmldir`、`scripts/cava.sh`；预期变更：共享 niri/CPU/MEM/NET/天气/Cava 状态、重连与限帧；完成标准：单例可加载并输出真实状态；验证方式：Quickshell 烟测与进程计数）。
- [√] 任务2（AFK）：交付跨桌面 Context Island（依赖：任务1；涉及文件：`components/ContextIsland.qml`、`components/NiriContext.qml`、`components/HyprlandContext.qml`、`components/DesktopContext.qml`、`components/FallbackContext.qml`、`components/WorkspaceStrip.qml`；预期变更：四种环境路由和真实状态映射；完成标准：niri 5-slot 分页、Hyprland active/occupied/empty、Desktop/Fallback 无伪 workspace；验证方式：静态解析与 niri 实机切换）。
- [√] 任务3（AFK）：交付固定 Clock 与工业 System 集群（依赖：任务1；涉及文件：`components/ClockIsland.qml`、`components/SystemIsland.qml`、`components/Metrics.qml`、`components/Spectrum.qml`、`components/Power.qml`、`components/TrayIsland.qml`；预期变更：38px 视觉、四指标、暗纹频谱、低权重托盘和线稿 Power；完成标准：数据、状态、hover 和动效符合设计契约；验证方式：QML 静态检查与托盘回归）。
- [√] 任务4（AFK）：装配三岛并实现响应式宽度预算（依赖：任务2、任务3；涉及文件：`Bar.qml`、`bar-layout-check.qml`；预期变更：三个顶层组件、五级响应式降级与几何自检；完成标准：2048/1280/1024/800 无重叠且隐藏顺序正确；验证方式：`bar-layout-check.qml`）。
- [√] 任务5（AFK）：同步设计契约并完成深度质量闭环（依赖：任务4；涉及文件：`.helloagents/DESIGN.md`、方案包、归档索引；预期变更：稳定 UI 规则、验证证据和归档；完成标准：静态检查、状态测试、运行日志和截图均通过；验证方式：qa-review 与真实 niri 截图）。

## Codex /goal 执行入口
按 `.helloagents/plans/202607281052_instrument-bar-redesign/tasks.md` 执行本方案；遵守 `requirements.md`、`plan.md`、`contract.json`。按顺序完成全部 AFK 任务，完成后进入深度 QA、写最新质量证据并完成 HelloAGENTS 收尾。

## 进度
全部任务已完成，正在归档方案与写入交付证据。
