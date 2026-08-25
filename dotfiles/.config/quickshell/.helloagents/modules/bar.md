# 模块: 桌面 Bar

## 用途
提供跨 niri、Hyprland、KDE/GNOME 与通用桌面会话的顶部状态栏，统一呈现上下文、时钟、系统指标、托盘和电源入口。

## 关键文件
- `config/BarTuning.qml`：唯一像素微调入口，集中管理三岛位置、宽度、字号、内部间距与响应式阈值。
- `Bar.qml`：三语义区装配、稳定视觉 token 与响应式宽度预算。
- `components/BarContour.qml`：以单个 Canvas 路径绘制全宽顶部连接带和三段反 R 角岛屿轮廓。
- `components/ScreenEdgeBorder.qml`、`ScreenEdgeBorderHost.qml`：把 Bar 方形外端以 `17px` 内凹角融入两侧 `6px` 屏幕轨道，复刻 Brain_Shell `Border.qml` 的实际外缘结构。
- `components/RightPanelController.qml`：统一控制页/通知页路由、同入口开关、跨页切换与退场窗口生命周期。
- `components/RightPanelHost.qml`：固定最大透明外窗，把 flare 上移到右岛底边接缝；打开时承载一次外部点击关闭，退场时输入 mask 跟随实际 sizer。
- `components/UnifiedRightPanel.qml`：使用宽度、高度和内容三个独立进度驱动右锚定 sizer，常驻 Control / History 页面并支持动画中途反向。
- `components/RightPanelShape.qml`：区分 `304px` 连接颈部、`560–640px` 主体和 `16px` flare 的线程化 Canvas 轮廓；按最终尺寸绘制，开合阶段只由 sizer 裁剪揭示。
- `components/AnimatedPanelPage.qml`：页面常驻包装器，只用透明度与 `12px` 水平位移切换内容。
- `components/RightPanelTabs.qml`、`RightPanelPageSwitcher.qml`：目标 `296×38px`、最小面板下不超过主体 `50%` 的单指示器分页轨道及 `58px` 页脚层。
- `components/NotificationHistoryPage.qml`：History 内容驱动高度和通知 ListView；标题、空态及加载/错误状态分别由 `NotificationHistoryHeader`、`NotificationHistoryEmptyState`、`NotificationHistoryStatusState` 承担，高度限制为 `460–640px`。
- `Niri.qml`：共享 niri workspace 数据、事件流与聚焦动作。
- `services/TopBarState.qml`：共享 CPU、MEM、NET、天气和 Cava 数据。
- `components/ImportedControlCenterPanel.qml`：右岛当前调用的唯一控制中心，在标题栏显示时间、日期与天气，并提供网络、蓝牙、音量、亮度、系统占用和媒体控制；按钮与媒体卡分别由 `ControlCenterHeaderButton`、`ControlCenterMediaCard` 承担。
- `components/ContextIsland.qml`：桌面环境路由与 Context 内容契约。
- `components/ClockIsland.qml`：时间、日期与轻量音量反馈；不再占用顶栏宽度显示天气。
- `components/SystemIsland.qml`：Metrics、Tray 与 Power 的右侧系统集群。
- `components/TrayIsland.qml`：消费持久通知历史来源计数，稳定排序托盘应用，维护动态槽位、复合入口和总数角标，并通过单个进程调用托盘窗口聚焦脚本。
- `components/TrayItem.qml`：单个托盘图标的 hover、右键菜单、键盘焦点、单击/双击消歧、激活行为与每应用通知角标。
- `components/TrayNotificationModel.js`：规范化 Desktop Entry/应用名，执行唯一匹配、受限 QQ 归属与稳定排序。
- `scripts/focus-tray-item.sh`：按托盘 `id/title/tooltipTitle` 对 niri 窗口进行确定性评分和最近聚焦；通知卡片继续使用 `focus-notification-source.sh`。回归 fixture 位于 `scripts/test-focus-tray-item.sh`。
- `bar-layout-check.qml`：2048/1280/1024/1008/1007/800/660 宽度的几何、阈值、反 R 角排除间距与退让顺序门禁。
- `tray-interaction-check.qml`：单击延迟激活、双击取消激活并聚焦、右键取消待执行单击的交互回归。
- `right-panel-state-check.qml`：控制/通知入口路由、同页关闭、跨页切换、退场生命周期与统一 token 门禁。
- `right-panel-animation-check.qml`：分阶段开关、页面交叉过渡、单通知高度、半途反向与减弱动效门禁。

## 依赖
依赖 Quickshell 0.3、QtQuick、SystemTray；niri 使用 `niri msg`，Hyprland 使用可选 `Quickshell.Hyprland`，频谱使用 Cava，天气沿用 Waybar weather 脚本。

## 经验
- [2026-07-28] 多屏 Bar 的长驻采集必须放在单例中，视图只按 screen/output 过滤；否则每块屏幕都会重复启动事件流和频谱进程。
- [2026-07-28] QML 紧凑组件应避开内建 `state` 命名，并用显式 Loader 绑定与 `ComponentBehavior: Bound` 固化作用域，不能只以运行时可加载作为静态质量标准。
- [2026-07-28] 会写持久数据的状态检查必须注入独立临时路径；视觉/布局测试同时使用 `QUICKSHELL_TEST_MODE=1`，避免触发真实采集和用户数据链路。
- [2026-07-28] 紧凑 Bar 应同时调整外框宽度、内部列宽、字体和溢出约束；只压缩 `implicitWidth` 会导致 Workspace 标记、指标值或 Tray 槽位越界。Tray 与 Power 保持独立表面，但可用 `4px` 二级间距形成统一工具组。
- [2026-07-28] 位置与尺寸常量必须集中在 `config/BarTuning.qml`；组件和测试共同消费该配置，避免手动微调后出现实现、响应式门禁与文档三处数值漂移。
- [2026-07-30] 中岛只承担时间与音量反馈，不再创建点击子面板；右岛仅保留当前控制中心，删除被替代的旧面板实现与无用采集链路。
- [2026-08-08] 托盘折叠宽度按实际应用数收缩，溢出仅占用复合入口；持久历史来源按 `desktopEntry`、`appName` 两阶段唯一匹配，计数降序且同数保持注册顺序，清空后实时恢复原序；临时通知分组不参与角标。
- [2026-08-08] `TrayItem` 的身份字段延迟更新通过显式 revision 触发重排；测试夹具使用 `values` 数组对象模型，避免在 Qt 6.11 下直接创建 `ObjectModel`。
- [2026-08-08] `TrayItem` 左键单击延迟消歧，双击调用独立托盘聚焦脚本，避免破坏通知卡片既有聚焦语义。
- [2026-08-08] 托盘来源计数恢复为持久历史裁剪池；`append/count/list/clear` 均返回并更新 `sourceCounts`，QQ 仅匹配唯一空标签 `chrome_status_icon_1`，VCP tooltip 非空时不会串号。
- [2026-08-08] 自动门禁通过：Python 通知历史、offscreen 托盘/存储/布局检查、托盘聚焦 fixture、锁屏 `qmllint` 与 `git diff --check`；真实托盘与锁屏认证仍需人工验收。
- [2026-08-09] 已移除的 `tests/` Edge-Integrated 原型只验证了贴顶布局框架与连续右岛；其单段椭圆不是最终目标几何，不再是活动测试入口。
- [2026-08-25] 生产 Bar 顶部及左右边距归零并采用 Brainitech/Brain_Shell 的 `40px` 高度、`6px` 顶部连接带、`15px` 上内凹/下外凸圆角与 `34px` 排除间距。全宽单路径避免接缝；System 的 Metrics/Tray/Power 共用连续外表面，Tray 展开面仍保持独立背景。
- [2026-08-25] Brain_Shell 截图中的左右外缘来自 `Border.qml`，不是 Bar 末端普通凸圆角：Bar 外端保持方形接缝，以 `17px` 内凹角收束到 `6px` 屏幕侧边轨道。控制中心和通知历史收敛为唯一双页右侧窗口；面板窗口上移一个 `15px` flare，动画只调整裁剪框，避免 4K/1.5× 下逐帧重绘和布局。
- [2026-08-25] 统一面板的外部点击层与内容必须属于同一个 PanelWindow；打开时输入区覆盖 Bar 底边以下，关闭时立即缩回动画面板区域，才能同时做到单击关闭和退场期间不吞桌面输入。
- [2026-08-25] 大型右面板不能把右岛宽度等同主体宽度，也不能同步动画窗口宽高。最终实现把右岛关闭态限制为 `218–240px`、打开颈部固定为 `304px`，主体宽度独立为 `560–640px`；固定外窗内按 `40/95/180ms` 依次启动横向、纵向和内容阶段，反向操作从当前进度继续。
- [2026-08-25] History 高度应由真实 ListView `contentHeight` 驱动并限制为 `460–640px`；页面和底部 Tab 只在壳内过渡，不能通过关闭/重开窗口切页。Control 目标高 `760px`，紧凑分页轨道固定 `296×38px`。
- [2026-08-25] 固定宿主上移 flare 时不能再次填充整块右岛颈部：主体仍从 `40px` Bar 底边开始，向上衔接只覆盖颈部边界左右各 `16px`；左侧形成反 R 弧，右侧消除右岛旧外凸角留下的月牙缺口，同时避开 Metrics/Tray/Power。History 切页也不得触发 Tray 全量图标展开。
