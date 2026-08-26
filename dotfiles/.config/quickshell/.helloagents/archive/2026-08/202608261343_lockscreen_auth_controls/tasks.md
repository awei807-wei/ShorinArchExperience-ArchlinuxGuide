# 锁屏认证与操作控件重构 — 任务分解

## 拆分原则
- 默认按端到端垂直切片拆分：每个任务交付一个可验证行为，而不是单独交付某一层。
- `AFK` 表示代理可独立完成；`HITL` 表示需要用户决策、外部凭据、人工视觉确认或手动验收。
- 厚任务必须继续拆小；横向前置任务只在确有技术依赖时保留。

## 任务列表
- [√] 任务1（AFK）：交付无字体依赖的右上角操作胶囊（依赖：无；涉及文件：`lockscreen/LockGlyph.qml`、`lockscreen/PowerControls.qml`、`lockscreen/power-controls-check.qml`；预期变更：确定性矢量图标、统一 rail、纯文字菜单；完成标准：几何和状态测试通过且无旧码点；验证方式：offscreen PowerControls 检查与 qmllint）。
- [√] 任务2（AFK）：交付一体化认证凭据控件（依赖：无；涉及文件：`lockscreen/LockscreenAuth.qml`、`lockscreen/shell.qml`、`lockscreen/lockscreen-auth-layout-check.qml`；预期变更：身份行、可见提示、内嵌按钮、固定状态槽、水平错误抖动和同步用户名；完成标准：PAM 边界不变且布局状态测试通过；验证方式：offscreen 认证布局检查与 qmllint）。
- [√] 任务3（AFK）：完成视觉、质量与知识闭环（依赖：任务1、任务2；涉及文件：`.helloagents/DESIGN.md`、`.helloagents/modules/lockscreen.md`、`.helloagents/verify.yaml`、`.helloagents/CHANGELOG.md`、方案包与会话证据；预期变更：记录稳定契约、验证命令和事实；完成标准：deep QA、视觉自检、归档和隔离本地提交完成；验证方式：定向测试、lint、源码扫描、diff/status 审计）。

## Codex /goal 执行入口
不需要外层长程目标；本轮按当前方案连续完成全部 AFK 任务。

## 进度
全部任务完成：完整门禁 `51/51` 通过，三种认证状态和 idle 两种状态完成隔离渲染复验，等待方案迁移与本地版本检查点。
