# 托盘通知排序与锁屏恢复 — 任务分解

## 拆分原则
- 默认按端到端垂直切片拆分：每个任务交付一个可验证行为，而不是单独交付某一层。
- `AFK` 表示代理可独立完成；`HITL` 表示需要用户决策、外部凭据、人工视觉确认或手动验收。
- 厚任务必须继续拆小；横向前置任务只在确有技术依赖时保留。

## 任务列表
- [√] 任务1（AFK）：交付托盘动态宽度与无持久灰框交互（依赖：无；涉及文件：`components/TrayIsland.qml`、`components/SystemIsland.qml`、`config/BarTuning.qml`、`Bar.qml`、`tray-state-check.qml`、`bar-layout-check.qml`；预期变更：0/1/2/3 应用状态按最小 1/1/2/3 槽位收缩，最多 3 个直接应用图标，删除鼠标点击后残留方框并保留键盘焦点；完成标准：布局矩阵、overflow、hover、菜单和键盘激活行为通过；验证方式：Quickshell 运行 `tray-state-check.qml`、`bar-layout-check.qml` 与实际 Bar 加载检查）。
- [√] 任务2（AFK）：恢复持久通知来源计数（依赖：无；涉及文件：`scripts/notification-history.py`、`scripts/test-notification-history.py`、`components/NotificationHistoryStore.qml`、`notification-store-check.qml`；预期变更：历史 `append/count/list/clear` 返回裁剪后 `sourceCounts`，Store 成功操作同步暴露，保留历史总数/列表/清空/损坏恢复；完成标准：来源路径归一到同一桶、11 项 Python 回归通过；验证方式：`python3 scripts/test-notification-history.py` 与 Quickshell 运行 `notification-store-check.qml`）。
- [√] 任务3（AFK）：交付持久历史驱动的稳定排序与每应用角标（依赖：任务1、任务2；涉及文件：`shell.qml`、`Bar.qml`、`components/SystemIsland.qml`、`components/TrayIsland.qml`、`components/TrayNotificationModel.js`、`tray-state-check.qml`；预期变更：贯穿 Store `sourceCounts`、两阶段唯一精确匹配、Fcitx/VCP/飞书/QQ fixture、QQ 受限空标签 fallback、计数降序/注册索引升序、危险色数字角标与清空复位；完成标准：QQ 获得角标且按数量前移、VCP 不串号、歧义拒绝、未知来源、同数稳定和实际 TrayItem 委托角标全部通过；验证方式：扩展 `tray-state-check.qml`、持久历史 fixture 与实际 Bar 视觉检查）。
- [√] 任务4（AFK）：从 Git 历史定向恢复独立锁屏（依赖：无；涉及文件：`lockscreen/shell.qml`；预期变更：比较 `909cf29`、`abf85bb` 及相邻版本，恢复锁定窗口、输入、PAM失败/成功与退出主链路，并适配当前 `lockscreen/config`；完成标准：niri 绑定指向的命令可加载，无缺失组件/QML语法错误，锁定和认证链路完整；验证方式：历史 diff 审计、Quickshell 加载日志、进程退出审计和真实锁定/解锁烟测）。
- [√] 任务5（AFK）：完成跨功能集成、质量闭环与知识同步（依赖：任务1-4；涉及文件：上述实现与检查文件、`.helloagents/DESIGN.md`、`.helloagents/modules/bar.md`、`.helloagents/CHANGELOG.md`、本方案包；预期变更：解决子代理并发修改冲突，统一数据接口与视觉 token，更新事实文档和任务状态；完成标准：deep QA 全部有结论、无敏感/无关变更、方案包可归档；验证方式：Python/QML 全套检查、Bar 与锁屏加载、关键状态视觉检查、`git diff --check`、`git status --short`）。
- [ ] 任务6（HITL）：确认真实托盘交互与锁屏认证体验（依赖：任务4、任务5；涉及文件：无；预期变更：在真实会话验证托盘点击/右键菜单/键盘焦点，并使用 niri `Mod+Alt+L` 完成一次错误密码反馈和一次正确密码解锁；完成标准：托盘交互无持久灰框、锁定不可绕过、输入焦点正常、PAM 认证成功后锁屏进程退出；验证方式：人工烟测并将结论写入最终质量记录）。

## Codex /goal 执行入口
`/goal 按 .helloagents/plans/202608081226_tray-notification-lockscreen-restore/tasks.md 执行本方案；遵守 requirements.md、plan.md、contract.json。默认主执行命令是 ~auto；按顺序完成所有 AFK 任务；HITL 仅在缺少外部决策、凭据或人工验收时暂停。不要把完整需求原文直接当作 /goal 目标。全部 AFK 任务完成后必须进入 ~qa，写最新质量证据并完成 HelloAGENTS 收尾，再标记 goal complete。`

## 进度
- 通知数据链研究已完成：已确认持久历史 `sourceCounts`、临时 `notificationGroups` 生命周期隔离、唯一匹配规则、排序规则与贯穿路径。
- 回归修复已补充：同 ID 替换通知的旧对象关闭/过期按 QObject identity 清理，生产 helper 与 `tray-state-check.qml` replacement fixture 共用 `TrayNotificationModel.removeNotificationByIdentity`。
- 跨应用替换和托盘计时器边界已补充：生产 helper 先清理旧分组再加入新应用；旧关闭/新关闭、键盘激活、隐藏项取消延迟单击均由门禁覆盖。
- 托盘布局与锁屏恢复由独立子代理并行施工；主代理负责方案协调、通知实现、集成与最终验证。
- 自动门禁已通过：`python3 scripts/test-notification-history.py`（11 项）、offscreen `tray-interaction-check.qml`、`tray-state-check.qml`（含 Fcitx/VCP/飞书/QQ 来源、QQ 歧义拒绝与清空复位）、`notification-store-check.qml`、`bar-layout-check.qml`、托盘聚焦 helper fixture、`qmllint lockscreen/shell.qml`、`git diff --check`。实机热重载确认 QQ 角标和排序生效，VCP 无串号，复合入口总计独立保留。
- 任务 1-5 已完成；方案包保持活跃，不归档。任务 6 仍等待真实托盘交互、错误密码反馈与 PAM 成功解锁人工验收。
