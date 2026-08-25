# 通知来源筛选 — 实施规划

## 架构映射
- `scripts/notification-history.py` 与 `shell.qml`：持久化并清洗可选 `appIcon`。
- `components/TrayNotificationModel.js`：统一托盘匹配、来源别名聚合、同托盘二次合并、排序和选择恢复。
- `components/SystemTrayModelBridge.qml`：把稳定 `SystemTray.items` 的内容变化转换为 revision。
- `components/NotificationSourceRail.qml` / `NotificationSourceTab.qml`：固定 ALL、应用横滚、图标回退、筛选、提示和菜单能力。
- `components/NotificationSourceMenuAnchor.qml`：隔离依赖真实 Wayland 窗口的 `QsMenuAnchor`。
- `NotificationHistoryPage` / `View` / `List`：筛选状态、短淡入淡出、过滤列表与现有历史状态机。
- `RightPanelHost` / `UnifiedRightPanel`：传递当前屏幕 `PanelWindow`、托盘模型和 revision。

## 实施顺序
1. 扩展历史快照和 Python 清洗器，补齐 `appIcon` 往返与旧记录兼容测试。
2. 抽出 `trayIndexForSource()`，让顶栏计数与 History 来源复用同一匹配规则。
3. 实现历史别名聚合、同托盘二次合并、托盘优先排序和选择恢复纯函数。
4. 先建立来源模型门禁，再接入来源 Tab、横滚 Rail 与原生菜单桥。
5. 拆分 History 的视图和列表职责，所有索引、键盘操作与空态改用过滤结果。
6. 沿右面板宿主链注入 `PanelWindow` 和托盘 revision，接入 Header 过滤计数与 `Clear all`。
7. 执行 QML/Python/运行时门禁，并在真实 niri 会话验证 QQ/Kitty 图标及 QQ 菜单锚点。

## 性能与稳定性
- 历史上限为 200 条，来源计算保持纯 JS 数组重算，不增加 Python 往返或持久状态。
- 系统托盘模型通过 revision 显式触发，来源对象只持有活的 `trayItem` 引用，不复制菜单对象。
- 来源切换期间禁用列表逐卡 add/remove 位移动画，只对列表整体透明度做两段短动画。
- `QsMenuAnchor` 仅在第一次请求原生菜单时同步加载，普通来源不实例化菜单桥。

## 风险控制
- Desktop Entry 多候选时禁止退化到宽松应用名匹配，避免将通知菜单归给错误应用。
- 右键不修改选中来源，避免菜单打开前列表重排造成锚点跳动。
- `Image.source` 按 URL 类型处理，显示状态只依据 `Image.Ready`，避免错误的字符串长度判断遮住已加载图标。
- 保留统一右侧面板固定 `760px` 外壳；来源栏只重新分配 History 页内视口，不触发外壳几何重建。
