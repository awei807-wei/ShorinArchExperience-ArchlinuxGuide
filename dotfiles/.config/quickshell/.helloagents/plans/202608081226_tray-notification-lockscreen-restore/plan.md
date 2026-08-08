# 托盘通知排序与锁屏恢复 — 实施规划

## 目标与范围
本次同时闭合三个相互独立但需要统一验收的行为：修正托盘点击后的持久灰框与动态宽度、把活动通知暂存池聚合为每应用排序/角标数据、从 Git 历史恢复 niri 快捷键指向的独立锁屏。Bar 继续保持最多 3 个直接应用图标和既有复合入口；锁屏只做定向恢复，不回退整个工作区。

## 架构与实现策略
- 托盘布局由 `TrayIsland.qml` 基于实际应用数计算基础槽位：0 个应用保留 1 个最小槽位，1/2/3 个应用分别占 1/2/3 个应用槽位；溢出或通知历史需要复合入口时按现有入口语义追加，不再无条件预留四个位置。`BarTuning.qml` 只提供单槽、间距、内边距和最小/最大宽度 token。
- 删除鼠标激活后残留的整块浅灰选中表现。hover 可使用短时表面反馈；键盘焦点改用不会覆盖图标的可见校准线/细边界，并确保鼠标激活后不形成持久选择态。
- `shell.qml` 从活动 `notificationGroups` 通过纯函数按 `(desktopEntry, appName)` 派生来源计数；通知加入、替换、关闭、退场或过期后同步更新。`NotificationHistoryStore.qml` 只常驻历史总数和串行队列，不再维护来源计数。
- 活动来源计数经 `shell.qml`、`Bar.qml`、`SystemIsland.qml` 传入 `TrayIsland.qml`；磁盘历史面板继续只消费 `historyCount`。
- `TrayIsland.qml` 为 SystemTray 原始注册序列建立稳定索引，使用确定性两阶段唯一匹配算法计算每项计数；以“计数降序、注册索引升序”生成展示模型。匹配失败或存在多个候选时计数为 0，禁止猜测。
- 每个已匹配且计数大于 0 的图标绘制紧凑危险色数字角标；角标不改变槽位宽度、不遮挡菜单/点击热区，并与复合入口上的历史总数保持不同语义。
- 锁屏恢复先比较 `909cf29`、`abf85bb` 及其相邻历史版本与当前 `lockscreen/shell.qml`，选择最后可加载且具备锁定/PAM链路的基线，再定向恢复缺失结构并适配当前 `lockscreen/config` 主题入口。禁止对无关文件做整提交回退。

## 领域语言
- “注册顺序”：`SystemTray.items` 提供应用时的原始顺序，是通知数相同和清零后的稳定次序。
- “来源计数”：磁盘通知历史中按 `(desktopEntry, appName)` 聚合的保留记录数，不定义为未读数。
- “直接应用图标”：折叠态真实展示的托盘应用图标，最多 3 个，不含复合入口。
- “复合入口”：现有隐藏应用/通知历史入口；其中 `+N` 仍只表示隐藏应用数。
- “锁屏恢复”：从历史提取有效实现并做当前兼容修正，不等于回退整个提交。

## 完成定义
- 0/1/2/3 个托盘应用分别使用最小 1、1、2、3 个应用槽位；4 个及以上应用最多直接显示 3 个，溢出可通过现有入口访问。
- 鼠标点击任意托盘图标后不残留浅灰方框；hover、右键菜单、键盘聚焦和 Enter/Space 激活仍可用。
- 活动通知来源、Fcitx/Chrome/Lark 精确匹配、歧义拒绝、排序示例和 `TrayItem.notificationCount` 委托角标全部由测试证明；关闭活动通知后顺序与角标恢复，磁盘历史总数独立保留。
- 每个匹配应用显示准确的历史通知数量角标，通知历史总角标、隐藏应用 `+N` 和每应用角标不混算。
- `Mod+Alt+L` 对应命令能够加载 `lockscreen/shell.qml`，锁定窗口与 PAM 解锁主链路无 QML 错误；恢复未引入历史媒体逻辑或无关回退。
- qaMode 为 deep；qaFocus 为托盘状态矩阵、来源唯一匹配、排序稳定性、计数/角标清零、通知存储兼容、锁屏加载与认证生命周期。

## 文件结构
- `components/TrayIsland.qml`：动态槽位、无持久灰框、稳定排序与每应用角标。
- `config/BarTuning.qml`：托盘尺寸 token 与最小/最大宽度派生。
- `components/SystemIsland.qml`、`Bar.qml`、`shell.qml`：来源计数数据贯穿。
- `components/TrayNotificationModel.js`：活动通知分组来源计数纯函数、精确匹配与稳定排序。
- `components/NotificationHistoryStore.qml`：仅历史总数与串行存储队列。
- `scripts/focus-tray-item.sh`、`scripts/test-focus-tray-item.sh`：托盘双击聚焦 helper 及 niri 窗口评分 fixture；`focus-notification-source.sh` 保持通知卡片原有语义。
- `scripts/test-notification-history.py`、`notification-store-check.qml`、`tray-state-check.qml`、`bar-layout-check.qml`：存储、桥接、排序、角标和布局回归。
- `lockscreen/shell.qml`：历史锁屏定向恢复与当前主题兼容。
- `.helloagents/DESIGN.md`、`.helloagents/modules/bar.md`、`.helloagents/CHANGELOG.md`：最终集成后同步事实与验证结论。

## UI / 设计约束
- 属于既有 Swiss editorial / 工业工作站风格的演进式修复，继续使用 `.helloagents/DESIGN.md` 的 40px 岛高、6px 圆角、暗色表面、冰蓝焦点和低饱和危险色。
- 每应用通知角标必须紧凑、可读且不扩张槽位；建议锚定图标右上角，数字与危险色同时表达状态，不使用发光、脉冲或缩放。
- 点击反馈和键盘焦点分离：鼠标点击不留下方框，键盘焦点仍可辨识；`QUICKSHELL_REDUCE_MOTION=1` 时关闭新增排序/宽度动效。
- 动态宽度变化保持 `120–180ms` 范围内的轻量过渡，0/1/2/3/溢出状态不应发生图标裁切、复合入口越界或 Power 工具组位移跳变。
- 锁屏延续历史有效视觉与当前主题 token，不借恢复任务重做构图或加入新视觉语言。

## 风险与验证
- 通知 `appName` 与托盘标题可能重名：只接受唯一精确匹配，构造重复候选测试证明不会误计数。
- `desktopEntry`、托盘 `id` 可能带路径、大小写或 `.desktop` 后缀：共享同一规范化函数语义并覆盖等价输入测试。
- QML 对 JS 数组排序和模型更新可能丢失注册索引：排序前复制轻量包装对象，保留原始 item 引用与固定 index，不修改 `SystemTray.items`。
- 活动通知与磁盘历史语义混淆会导致角标虚高：明确 `notificationGroups` 只表示当前活动临时池，`historyCount` 只表示历史面板总数，禁止跨层聚合。
- 角标可能被 `clip` 或菜单锚点遮挡：用布局状态检查和实际 Bar 加载检查图标边界、点击热区与 QsMenuAnchor。
- 锁屏历史版本可能依赖已删除组件：以锁定/PAM最小闭环为证据，逐项移植，遇到媒体或视觉附属依赖时裁剪而非连带恢复。
- 验证顺序为 Python 单测、QML 状态检查、Bar/锁屏实际加载日志、关键状态视觉检查、`git diff --check` 和工作区审计；锁屏真实密码成功解锁由人工烟测记录结论。

## 决策记录
- [2026-08-08] 通知来源计数以磁盘历史为唯一真实来源，不新增未读状态或第二套缓存。
- [2026-08-08] 采用 `desktopEntry -> tray.id`、`appName -> tray.id/title/tooltipTitle` 的两阶段唯一精确匹配；歧义与未知来源宁可不计，不做猜测。
- [2026-08-08] 排序固定为通知数降序、SystemTray 注册顺序升序，确保通知清零后可逆恢复。
- [2026-08-08] 锁屏从历史做文件级恢复与当前兼容，不对仓库执行整提交回退。
