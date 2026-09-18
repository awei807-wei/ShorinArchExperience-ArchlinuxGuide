# 模块: 桌面 Bar

## 用途
提供跨 niri、Hyprland、KDE/GNOME 与通用桌面会话的顶部状态栏，统一呈现上下文、时钟、系统指标、托盘和电源入口。

## 关键文件
- `config/BarTuning.qml`：唯一像素微调入口，集中管理三岛位置、宽度、字号、内部间距与响应式阈值。
- `Bar.qml`：三语义区装配、稳定视觉 token 与响应式宽度预算；右岛保持无动态底纹的纯净深色表面。
- `components/BarContour.qml`：以单个 Canvas 路径绘制全宽顶部连接带和三段反 R 角岛屿轮廓。
- `components/ScreenEdgeBorder.qml`、`ScreenEdgeBorderHost.qml`：把 Bar 方形外端以 `17px` 内凹角融入两侧 `6px` 屏幕轨道，复刻 Brain_Shell `Border.qml` 的实际外缘结构。
- `components/RightPanelController.qml`：统一控制页/通知页路由、同入口开关、触发屏幕、右岛起始/目标颈宽、唯一 `rightPanelProgress` 与退场窗口生命周期。
- `components/RightPanelHost.qml`：每屏一个常驻映射、只覆盖面板最终几何的 Top 层窗口；flare 上移到右岛底边接缝，输入 mask 只在 `windowVisible` 期间跟随 reveal viewport 的可见主体并避开 Bar 接缝，关闭态为空区域。
- `components/RightPanelGeometry.js`：右面板宽度与内容高度的纯函数，`RightPanelHost` 与 `PanelOutsideClickCatcher` 共用。
- `components/PanelOutsideClickCatcher.qml`：任一面板打开时映射的全屏透明 Top 层窗口，点击面板外或 Esc 关闭全部面板；输入区域用减法 Region 扣除两个面板矩形。
- `components/CenterPanelController.qml`、`CenterDashboard.qml`：中岛子面板的单一进度时钟与常驻内容窗口；内容按最终尺寸布局、由裁剪逐步显露，透明度随 `smoothstep(0.30, 0.90)` 派生，Home 页常驻渲染，频谱采集在完全展开后才拉起。
- `components/NotificationPopupStack.qml`：临时通知浮层的增量卡片栈，按应用键复用 `NotificationPopupGroup`，消失的分组先播退场再销毁；宿主窗口固定尺寸常驻，输入区域跟随卡片列高度。
- `components/UnifiedRightPanel.qml`：以共享进度和触发 Bar 的两个颈宽端点驱动右锚定 reveal viewport；surface 空间允许时从 `54px` 安全高度揭示固定最终外壳，主体和内容进度只做阈值派生，常驻 Control / History 页面支持动画中途反向。
- `components/RightPanelShape.qml`：用单个最终尺寸 Canvas 绘制 `304px` 连接颈部、`560–640px` 主体、`16px` flare 与 `18px` 圆角；动画期间纹理尺寸和路径拓扑不变，只水平平移以对齐 Bar 的活动颈部。
- `components/AnimatedPanelPage.qml`：页面常驻包装器，始终保持 `visible`，通过同时进行的交叉淡入淡出、方向相反的 `28px` 水平位移和 `0.985→1` 轻量缩放切换整页内容，并在卡片完全就位后恢复输入。
- `components/RightPanelTabs.qml`、`RightPanelPageSwitcher.qml`：目标 `296×38px`、最小面板下不超过主体 `50%` 的单指示器分页轨道及 `58px` 页脚层。
- `components/NotificationHistoryPage.qml`：History 与 Control 共用固定面板高度，通知溢出时由 ListView 内部滚动；标题、空态及加载/错误状态分别由 `NotificationHistoryHeader`、`NotificationHistoryEmptyState`、`NotificationHistoryStatusState` 承担。
- `Niri.qml`：共享 niri workspace 数据、事件流与聚焦动作。
- `services/TopBarState.qml`：共享 CPU、RAM、BAT 和天气数据；BAT 通过 Quickshell UPower 读取并覆盖无电池环境。
- `components/ImportedControlCenterPanel.qml`：右岛当前调用的唯一控制中心，在标题栏显示时间、日期与天气，并提供网络、蓝牙、音量、亮度、系统占用和媒体控制；按钮与媒体卡分别由 `ControlCenterHeaderButton`、`ControlCenterMediaCard` 承担。
- `components/ContextIsland.qml`：桌面环境路由与 Context 内容契约。
- `components/ClockIsland.qml`：时间、日期与轻量音量反馈；不再占用顶栏宽度显示天气。
- `components/SystemIsland.qml`：Metrics、Tray 与 Power 的右侧系统集群，负责把共享 CPU/RAM/BAT 状态注入固定宽度遥测岛。
- `components/Metrics.qml`：在 `164px` 固定预算内呈现 CPU / RAM / BAT 三段等宽遥测、暗色斜杠栅栏和无电池健康绿兜底。
- `components/TelemetryMetricCell.qml`：保证标签与数值原生像素渲染、水平基线对齐及固定值槽宽度，不通过图层缩放压缩字形。
- `components/TrayIsland.qml`：消费持久通知历史来源计数，稳定排序托盘应用，维护动态槽位、复合入口和总数角标，并通过单个进程调用托盘窗口聚焦脚本。
- `components/TrayItem.qml`：单个托盘图标的 hover、右键菜单、键盘焦点、单击/双击消歧、激活行为与每应用通知角标。
- `components/TrayNotificationModel.js`：规范化 Desktop Entry/应用名，执行唯一匹配、受限 QQ 归属与稳定排序。
- `scripts/focus-tray-item.sh`：按托盘 `id/title/tooltipTitle` 对 niri 窗口进行确定性评分和最近聚焦；通知卡片继续使用 `focus-notification-source.sh`。回归 fixture 位于 `scripts/test-focus-tray-item.sh`。
- `bar-layout-check.qml`：2048/1280/1024/1008/1007/800/660 宽度的几何、阈值、反 R 角排除间距与退让顺序门禁。
- `tray-interaction-check.qml`：单击延迟激活、双击取消激活并聚焦、右键取消待执行单击的交互回归。
- `right-panel-state-check.qml`：控制/通知入口路由、同屏同页关闭、关闭中跨屏从 `0` 重新定向、受限目标颈宽、退场生命周期与统一 token 门禁。
- `right-panel-animation-check.qml`：共享进度、`54px` 安全揭示、固定 Canvas 拓扑、常规/受限目标下的 Bar/flare 逐帧对齐、真实动画单调推进与阶段自洽、双向页面卡片交叉过渡、半途反向与减弱动效门禁。
- `notification-popup-stack-check.qml`：分组数组整体替换时卡片不重建、消失分组先退场后销毁、退场期间同应用另起新卡片的回归门禁。

## 依赖
依赖 Quickshell 0.3、QtQuick、SystemTray 与 UPower；niri 使用 `niri msg`，Hyprland 使用可选 `Quickshell.Hyprland`，天气沿用 Waybar weather 脚本。

## 经验
- [2026-07-28] 多屏 Bar 的长驻采集必须放在单例中，视图只按 screen/output 过滤；否则每块屏幕都会重复启动事件流和系统采集进程。
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
- [2026-08-25] Brain_Shell 截图中的左右外缘来自 `Border.qml`，不是 Bar 末端普通凸圆角：Bar 外端保持方形接缝，以 `17px` 内凹角收束到 `6px` 屏幕侧边轨道。控制中心和通知历史收敛为唯一双页右侧窗口；面板窗口上移一个 `16px` flare，窗口尺寸与锚点保持固定。
- [2026-08-25] 统一面板的外部点击层与内容必须属于同一个 PanelWindow；打开时输入区覆盖 Bar 底边以下，关闭时立即缩回动画面板区域，才能同时做到单击关闭和退场期间不吞桌面输入。
- [2026-08-25] 大型右面板不能把右岛宽度等同主体宽度，也不能动画 Wayland 窗口本身。右岛关闭态限制为 `218–240px`、打开颈部固定为 `304px`，主体宽度独立为 `560–640px`；固定外窗内的 Bar 与 reveal viewport 读取同一进度，反向操作从当前值继续。
- [2026-08-25] Control 与 History 应共用 `760px` 目标高度并受屏幕可用高度统一限制；History 内容溢出时只滚动 ListView，页面和底部 Tab 在固定外壳内过渡，不能通过关闭/重开窗口切页。紧凑分页轨道固定 `296×38px`。
- [2026-08-25] 固定宿主上移 flare 时不能再次填充整块右岛颈部：主体仍从 `40px` Bar 底边开始，向上衔接只覆盖颈部边界左右各 `16px`；左侧形成反 R 弧，右侧消除右岛旧外凸角留下的月牙缺口，同时避开 Metrics/Tray/Power。History 切页也不得触发 Tray 全量图标展开。
- [2026-08-25] 页面切换不能 resize 线程化 Canvas：裁剪区会先变化，而新纹理异步完成前会短暂露出壁纸。两页因此共用固定高度，跨页只对常驻内容执行位移、淡入淡出和轻量卡片缩放。
- [2026-08-26] 连体外壳不能让宽度、高度与 Bar 错峰：`16–52px` 低高度无法容纳 flare 与两个 `18px` 圆角，会产生 GIF 中的凹口。最终实现使用一条 `300ms InOutCubic` 进度，Canvas 始终保持最终拓扑，viewport 在 surface 允许时从 `54px` 安全高度揭示；前 `10%` 只展开 Bar，内容从 `52%` 后进入。Controller 从触发屏幕捕获右岛起始/目标宽度，固定 Canvas 只做水平平移，使常规与窄屏受限颈部都逐帧一致；其他屏幕实例保持关闭。
- [2026-09-14] Metrics 不应靠缩小、缩放或负字距硬压缩字形承载四项监控。右岛总预算保持 `240px`，隐藏直出 Tray 槽并将 `164px` 分配给 CPU / RAM / BAT 三个等宽固定值槽，使用 `9/11px` Consolas 原生渲染等宽字、完整 hinting、两个 `10px` 斜杠栅栏与 `12px` 工具组间距。Tray 外壳为 `30×40px`，其复合入口命中区扩至 `24×24px`，Power 命中区为 `30×40px`。网络吞吐与 Cava 采集随展示一并删除；UPower 未就绪或无电池时 BAT 必须常驻为绿色 `100%`，避免布局坍塌。
- [2026-09-18] 动画顿挫的根因不是动画时钟：隔离探针证明 Quickshell 默认 basic 渲染循环下 300ms 动画稳定 16.0ms/帧。真实 shell 探针（临时 FrameAnimation 直接驱动 controller.togglePage）测出中岛打开在内容显露帧停顿 40–58ms、右面板首次位移 66–122ms、切页 90ms，来源都是面板窗口随开合重建与用 visible 卸载内容后的首帧重建；进程 fork 本身只有 0–1ms。窗口常驻 + 只动裁剪/透明度 + 启动预热后，开合全程 15–17ms/帧。Repeater 直接绑定 JS 数组会在数组任何变化时销毁并重建全部代理，通知浮层必须按键增量维护。切勿把 `QSG_RENDER_LOOP=threaded` 当作修复：它在窗口映射时反而多出 40ms 停顿。
- [2026-09-18] Quickshell 的空 Region mask 会下发空的 wl_region（完全穿透），根 Region 加 `Intersection.Subtract` 子区域会被拆成围绕孔洞的多个矩形下发，可放心用于常驻透明窗口与外部点击捕获层。热重载只响应原地写入，`mv` 覆盖文件不会触发。
