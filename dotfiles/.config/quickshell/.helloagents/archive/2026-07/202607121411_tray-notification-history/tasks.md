# 托盘通知历史 — 任务分解

## 拆分原则
- 默认按端到端垂直切片拆分：每个任务交付一个可验证行为，而不是单独交付某一层。
- `AFK` 表示代理可独立完成；`HITL` 表示需要用户决策、外部凭据、人工视觉确认或手动验收。
- 厚任务必须继续拆小；横向前置任务只在确有技术依赖时保留。

## 任务列表
- [√] 任务1（AFK）：交付受限磁盘历史（依赖：无；涉及文件：`scripts/notification-history.py`、`scripts/test-notification-history.py`、`components/NotificationHistoryStore.qml`；预期变更：原子 JSON、0600、串行队列、count/list/append/clear/copy；完成标准：历史双上限、损坏恢复和清空闭环通过；验证方式：`python3 scripts/test-notification-history.py`）。
- [√] 任务2（AFK）：交付复合托盘入口（依赖：任务1；涉及文件：`components/RightIslands.qml`、`Bar.qml`、`shell.qml`；预期变更：3 个直显图标、独立隐藏应用数与通知徽标、统一展开状态；完成标准：4→3+1、6→3+3、仅通知不显示 +0；验证方式：静态状态矩阵审查与 Quickshell 加载日志）。
- [√] 任务3（AFK）：交付磁盘驱动的单卡片面板（依赖：任务1、任务2；涉及文件：`components/TrayNotificationPanel.qml`、`shell.qml`；预期变更：同宽向下展开、滚轮/键盘切换、点击复制、图形清理、加载/空/错误反馈；完成标准：只创建当前卡片且清理同步归零；验证方式：通知注入、剪贴板读取和关键状态视觉检查）。
- [√] 任务4（AFK）：闭合通知生命周期与质量证据（依赖：任务1-3；涉及文件：`shell.qml`、`.helloagents/DESIGN.md`、方案包与归档；预期变更：淘汰通知及时 expire、契约同步、验证记录；完成标准：无隐藏 tracked 对象路径，测试与检查全部有结论；验证方式：`git diff --check`、脚本测试、Quickshell 实际加载和 Git 状态审计）。

## Codex /goal 执行入口
`/goal 按 .helloagents/plans/202607121411_tray-notification-history/tasks.md 执行本方案；遵守 requirements.md、plan.md、contract.json。默认主执行命令是 ~auto；按顺序完成所有 AFK 任务；HITL 仅在缺少外部决策、凭据或人工验收时暂停。不要把完整 PRD 原文直接当作 /goal 目标。全部 AFK 任务完成后必须进入 ~qa，写最新质量证据并完成 HelloAGENTS 收尾，再标记 goal complete。`

## 进度
- 已完成需求确认、方案设计、全部四项实施任务、深度质量闭环与视觉验收。
