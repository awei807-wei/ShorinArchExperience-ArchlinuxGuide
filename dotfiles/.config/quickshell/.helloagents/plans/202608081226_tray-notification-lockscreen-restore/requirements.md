# 托盘通知排序与锁屏恢复 — 需求

已按用户当前指令确认并冻结。执行阶段如需改变通知匹配规则、托盘槽位语义或锁屏触发方式，必须回到设计阶段重新确认。

## 核心目标
- 修复顶部 Bar 的托盘交互与布局：鼠标点击应用图标后不再残留浅灰方框，托盘基础宽度随实际应用数量收缩，直接展示的应用图标最多 3 个。
- 复用现有通知历史暂存池，为托盘应用提供通知计数、按计数动态排序和图标角标；通知越多越靠前，计数相同保持 SystemTray 注册顺序。
- 从 Git 历史核对并恢复可由 niri `Mod+Alt+L` 调起的 Quickshell 锁屏，不破坏当前主题和其他 Bar 功能。

## 功能边界
- 托盘在 0 个应用时保留 1 个槽位的最小表面；1、2、3 个应用时分别按 1、2、3 个应用槽位展开，直接应用图标上限为 3。
- 超过 3 个应用时沿用现有溢出/展开入口；通知历史入口与隐藏应用计数继续保持独立语义，不把应用通知数并入 `+N`。
- 鼠标点击应用后不得留下覆盖图标的浅灰选择框；hover 反馈和键盘可见焦点仍需保留，但焦点反馈不能表现为持久的整块浅灰方框。
- 每应用计数取自磁盘通知历史的裁剪后记录。存储响应提供 `sourceCounts[{desktopEntry,appName,count}]`，计数变化必须同步到 Bar。
- 通知源先用规范化后的 `desktopEntry` 唯一精确匹配托盘 `id`；未命中时再用规范化后的 `appName` 唯一精确匹配托盘 `id`、`title`、`tooltipTitle`。规范化包括去首尾空白、转小写、取 basename、去 `.desktop` 后缀；歧义或未知来源不计入任何托盘图标。
- 托盘排序按应用通知数降序，其次按 SystemTray 注册顺序升序。通知计数清零后恢复注册顺序；示例顺序必须满足 `1/2/3/4 -> 4/1/2/3 -> 3/4/1/2`。
- 匹配成功且计数大于 0 时，在对应托盘图标上显示数字角标；清空通知历史后角标和排序同步复位。
- 锁屏入口保持用户现有 niri 绑定：`/usr/bin/quickshell -p ~/.config/quickshell/lockscreen/shell.qml`。恢复以 Git 历史中最后可工作的锁屏为依据，只做目标文件级恢复与兼容修正。

## 非目标
- 不引入第二套通知存储、未读状态或独立托盘计数数据库。
- 不用模糊包含、部分字符串或多候选猜测来强行关联通知与托盘应用。
- 不改变通知历史面板的单卡片浏览、复制、清空和磁盘上限语义。
- 不重做 Bar、控制中心或锁屏的整体视觉风格，不改 niri 快捷键文件。
- 不恢复历史锁屏中已删除或不稳定的媒体控制链路，除非它是锁屏可加载的必要依赖。

## 技术约束
- 兼容当前 Quickshell、QtQuick、Wayland/niri 与现有 `SystemTray.items` 数据结构；托盘项没有可依赖的 `desktopEntry` 属性。
- 通知计数唯一来源为 `scripts/notification-history.py` 管理的磁盘历史，由 `NotificationHistoryStore.qml -> shell.qml -> Bar.qml -> SystemIsland.qml -> TrayIsland.qml` 单向贯穿。
- 保持通知历史文件的 200 条、2 MiB、原子写入、0600 权限和损坏恢复约束；计数必须基于裁剪后的最终历史。
- Bar 尺寸继续由 `config/BarTuning.qml` 集中管理，组件与状态检查消费同一配置。
- 锁屏继续以独立 Quickshell 配置运行，不直接复制或硬编码主配置中的运行时对象。

## 质量要求
- Python 回归覆盖 `sourceCounts` 的追加、裁剪、清空、同源聚合和响应兼容；QML 状态检查覆盖匹配、歧义拒绝、排序稳定性、角标清零及 0/1/2/3/溢出布局矩阵。
- 通过 `scripts/test-notification-history.py`、`notification-store-check.qml`、`tray-state-check.qml`、`bar-layout-check.qml`、QML 静态/实际加载检查与 `git diff --check`。
- 锁屏需验证历史来源、QML 可加载、niri 命令路径可达、锁定层创建、PAM 输入/失败/成功解锁链路；无法自动完成的真实输入验收必须明确记录。
- 延续 `.helloagents/DESIGN.md` 的 Bar 几何、暗色 token、危险色角标、键盘焦点、减弱动效与多宽度响应式要求。
