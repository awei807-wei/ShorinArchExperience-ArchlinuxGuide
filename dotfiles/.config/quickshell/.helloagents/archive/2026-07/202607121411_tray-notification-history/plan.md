# 托盘通知历史 — 实施规划

## 目标与范围
在现有右侧托盘岛中加入复合入口和向下展开的通知历史面板。历史以磁盘为唯一真实来源，QML 仅保存轻量计数、待写队列和当前面板的一份临时列表；交付后通知数量有硬上限，托盘溢出和通知统计互不污染。

## 架构与实现策略
- 使用独立 Python 标准库脚本负责 append/list/count/clear，完成目录创建、文件锁、原子替换、0600 权限及双上限裁剪。选择短生命周期子进程而非常驻 JsonAdapter，避免面板关闭后仍持有完整 JSON。
- 使用 `NotificationHistoryStore.qml` 串行调度持久化命令。通知到达时只排队压平后的快照，待写追加限制为 200 条；读取结果通过信号交给可见面板，面板关闭立即丢弃数组。
- `NotificationServer` 收到通知后先提交快照，再管理临时浮窗。每个被可见队列淘汰的对象立即 `expire()`，消除现有隐藏驻留路径。
- `RightIslands` 固定直接展示 3 个托盘图标。`hiddenTrayCount = max(0, trayCount - 3)`；复合入口在隐藏应用或历史通知任一存在时显示，中心 `+N` 只绑定隐藏应用数，通知徽标只绑定历史总数。
- 入口打开后，原托盘行向左扩展；独立全屏透明层在顶栏下方承载同宽通知面板，并处理外部点击关闭。一次只渲染当前卡片，其余堆叠效果由静态轮廓实现。
- 通过 `wl-copy` 写入格式化纯文本；显示层强制 PlainText，避免通知正文被当作富文本解释。

## 领域语言
- “隐藏应用数”：当前托盘图标总数减去 3，仅用于 `+N`。
- “历史通知数”：磁盘中保留的记录数量，仅用于数字徽标。
- “复合入口”：承载 `+N`、通知占位图形和通知数字徽标的第 4 个槽位。
- 避免把历史通知数称为“未读数”。

## 完成定义
- 4 个托盘图标显示 3 个应用和 `+1`；6 个显示 3 个应用和 `+3`。
- 仅有通知而无隐藏应用时显示通知入口且不显示 `+0`。
- 点击入口可展开托盘与通知面板；滚轮切换单卡片，点击复制，清理后磁盘与徽标同步为零。
- 历史文件始终满足 200 条、2 MiB、0600 与有效 JSON；损坏文件可隔离并恢复。
- qaMode 为 deep；qaFocus 为通知生命周期、磁盘一致性、复合入口状态矩阵、面板单实例渲染和清理闭环。

## 文件结构
- `scripts/notification-history.py`：磁盘存储命令与安全裁剪。
- `scripts/test-notification-history.py`：存储行为回归测试。
- `components/NotificationHistoryStore.qml`：异步队列与剪贴板桥接。
- `components/NotificationHistoryPanelHost.qml`：多屏窗口、外部点击与键盘焦点宿主。
- `components/TrayNotificationPanel.qml`：单卡片通知面板。
- `components/NotificationCardStack.qml`：单张真实卡片与两层静态轮廓。
- `components/NotificationPanelFooter.qml`：滚轮/键盘提示与图形清理操作区。
- `components/TrayIsland.qml`：三应用槽位、复合入口及同宽展开条。
- `components/RightIslands.qml`、`Bar.qml`、`shell.qml`：状态贯穿、托盘入口、窗口与通知生命周期。
- `tray-state-check.qml`、`notification-store-check.qml`、`notification-panel-state-check.qml`：QML 状态矩阵与进程桥检查。
- `.helloagents/DESIGN.md`：稳定视觉和交互约束。

## UI / 设计约束
- 延续现有 Cyber-Zen 深色、细边框、JetBrainsMono Nerd Font 和克制低饱和配色，不引入新 UI 库。
- 记忆点是“横向托盘条向下折叠成通知卡片盒”；宽度一致，边界连续，避免独立浮层的割裂感。
- 通知卡片是真实交互容器；只绘制两层静态后卡轮廓，不批量创建历史 delegate。
- 复制使用明确的 `COPIED` 反馈；加载、空、错误和清理状态使用文本与图形共同表达，不只靠颜色。
- 面板支持滚轮、上下键、Enter 复制和 Escape 关闭；交互热区不小于现有托盘槽位。

## 风险与验证
- QML 多屏实例可能重复读取：存储调度器只在 ShellRoot 创建一次，面板实例通过信号消费数据。
- 子进程突发覆盖：使用 QML 串行队列与磁盘 flock 双保险。
- 历史文件损坏：移动为时间戳 `.corrupt` 备份后重建空文件，并在面板显示可恢复错误。
- 损坏副本最多保留 3 个且总量不超过 2 MiB；超大历史在 JSON 解析前处理，避免异常内存峰值。
- PanelWindow 层级可能遮挡顶栏：历史窗口顶部边距从顶栏底部开始，保留顶栏托盘交互。
- 使用 Python 单元测试、`git diff --check`、QML/Quickshell 加载日志与关键状态截图或结构化视觉检查验证。

## 决策记录
- [2026-07-12] 确认 `+N` 只表示隐藏应用，通知数量使用独立徽标。
- [2026-07-12] 确认磁盘为历史唯一来源，面板一次仅展示一张卡片。
- [2026-07-12] 采用短生命周期 Python 标准库存储器，以满足原子写入、权限和关闭面板后释放历史数组的约束。
