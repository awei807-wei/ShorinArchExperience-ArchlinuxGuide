# 变更日志

## [未发布] - 2026-08-09
### 新增
- **[控制中心]**: 音量卡片新增 PipeWire 音频输出设备选择，可过滤硬件 sink、稳定显示当前默认输出并写入首选默认设备。
- **[控制中心]**: 新增音频输出模型与卡片展开交互的隔离自动化检查。
- **[Tray]**: 新增基于持久通知历史来源计数的托盘稳定排序与每应用危险色角标，计数相同时保持 SystemTray 注册顺序；历史总计与应用角标共享同一裁剪后来源池。
- **[锁屏]**: 恢复独立 Wayland 锁屏入口，改用 `lockscreen/config` 共享主题，并支持按 `HOME` 编码动态读取用户状态文件。
- **[锁屏]**: 抽取右上角 `PowerControls` 布局组件，统一使用 `JetBrainsMono Nerd Font` 的 power/eye glyph 与填充式居中对齐，修复 emoji/font fallback 导致的图标视觉垂直漂移。
- **[Bar 测试原型]**: 新增与生产 Bar 隔离的 `tests/` Edge-Integrated Contoured Bar 预览，包含左/中/右三功能区，右侧以单一连续右岛承载 Metrics/Tray/Power，并通过细铜色分隔与固定 mock 保持信息层级，不接入生产服务。

### 变更
- **[控制中心]**: 设备候选改为在音量卡片内部向下展开，文字整行居中、当前项勾选贴右，选择后自动收起且不覆盖亮度卡片。
- **[Bar 测试原型]**: 将 Metrics/Tray/Power 收敛为单一连续右岛，并把三岛轮廓改为 rail-attached 下伸结构：约 9px 连续深色 rail，rail 下方连接曲线的水平 `joinWidth` 为 18–20px（仅表示水平宽度），使用四分之一椭圆 cubic 从 `railBottom` 延伸到 `visibleBottom`，垂直高度覆盖完整岛体下伸高度并直接接平底；已移除短圆角后的垂直侧边和独立 `bottomRadius`，不再使用独立胶囊顶边、金色顶部描边或 literal triangle。左岛贴屏幕左边且只保留右转角，中岛保留双侧转角，右岛贴屏幕右边且只保留左转角；本轮仅修改 `tests` 原型，不改生产 Bar。
- **[Tray]**: 折叠宽度按实际应用数动态收缩，最多显示 3 个直接应用图标；身份字段延迟更新时通过 revision 触发重新排序。
- **[锁屏]**: PAM 用户从运行时用户名和环境变量解析，缺少用户名时显式报告认证失败，不再回退到硬编码用户。
- **[Tray]**: 左键单击延迟到系统双击间隔后激活，双击改为调用独立托盘窗口聚焦脚本；右键菜单不会触发激活或聚焦。
- **[通知]**: 修复同 ID 通知替换后旧对象 `closed/expire` 误删新对象的活动队列竞态，清理改按 QObject identity。
- **[通知]**: 替换通知进入时先跨应用清理旧分组，旧对象关闭不会删除新应用分组；键盘激活、隐藏和销毁托盘项会取消待执行单击计时器。
- **[通知]**: 恢复历史存储 `append/count/list/clear` 的 `sourceCounts` 响应并贯穿 Bar；来源按规范化身份聚合，QQ 仅在唯一空标签 `chrome_status_icon_1` 候选下归属，避免与 VCP 串号。

### 修复
- **[Bar 测试原型]**: 新增 `tests/shell.qml` 到 `edge-integrated-preview.qml` 的相对符号链接，使通过 `quickshell -p tests/` 或 `~/.config/quickshell/tests/` 目录入口启动预览时能够正确找到 shell 文件。

### 验证
- 音频输出模型、音量卡片展开/收起、相关 QML lint、Bar/Tray/通知/锁屏离屏门禁、通知历史 11 项、托盘聚焦 fixture、Edge-Integrated 布局与 `git diff --check` 通过；真实 Wayland 会话视觉验收通过。
- 自动门禁通过：Python 通知历史 11 项、offscreen 托盘交互/托盘状态（含 Fcitx/VCP/飞书/QQ 来源、QQ 歧义拒绝与清空复位）/存储/布局检查、托盘聚焦匹配 fixture、`qmllint lockscreen/shell.qml` 与 `git diff --check`。
- 锁屏布局门禁通过：`power-controls-check.qml` 在不启动 `WlSessionLock`、`Process` 或系统命令的前提下验证两个圆按钮尺寸/垂直中心、确定性 glyph 字体、图标填充对齐和展开菜单锚定；高 DPI/真实锁屏墨迹中心仍需人工视觉复验。
- Edge-Integrated Bar 原型门禁通过：固定 mock 下覆盖 2048/1600/1280/800 宽度，验证左/中/右三功能区、连续右岛与 full-height rail-attached 下伸轮廓的边界及内容不溢出；全量 QML lint 与布局门禁通过，实机截图记录于 `/tmp/tests-full-height-corners.png`，预览不会连接生产采集链路。
- 真实托盘双击聚焦、通知角标/排序、右键菜单、键盘焦点以及错误密码/正确密码解锁仍待人工验收。

## [0.1.0] - 2026-07-28
### 新增
- **[控制中心]**: 移植 `tripathiji1312/quickshell` 的右侧控制中心布局，接入 Wi-Fi、蓝牙、音量、亮度、CPU、内存、磁盘与 MPRIS 媒体状态。
- **[Bar]**: 新增 niri、Hyprland、KDE/GNOME 与通用会话的 Context 路由组件。
- **[Bar]**: 新增共享 NET/MEM/CPU/天气/Cava 状态、四项系统仪表、背景频谱与响应式布局检查。
- **[通知]**: 新增按应用分组的临时通知，支持折叠展开、完整正文、原生操作按钮与平滑过渡。
- **[测试]**: 为通知存储状态检查增加独立历史路径，避免测试读写真实通知历史。

### 变更
- **[天气]**: 从中岛移除天气，将实时天气放到右侧控制中心标题栏的时间右边，并由 `clockWeatherFontSize` 统一控制字号。
- **[右岛]**: 点击指标区调用新控制中心，并删除已被替代的旧 `SystemPanel.qml`。
- **[中岛]**: 删除中岛点击子面板、相关事件状态和 `CenterPanel.qml`，保留时间、日期与音量反馈。
- **[清理]**: 删除用于参考源码的 `tests/shell/` 克隆目录及旧面板专用系统采集链路。
- **[Bar]**: 将旧 Left/Center/Right 视图树重构为 Context/Clock/System 三个语义区域，并固定为 38px Swiss industrial 视觉。
- **[Bar]**: 收紧 Context/Clock/Metrics/Tray 宽度，放大 Workspace、时间与指标文字，降低频谱对比并将 Tray/Power 间距缩至 4px。
- **[Bar]**: 新增 `config/BarTuning.qml` 像素微调入口，集中管理三岛位置、尺寸、字号、间距、响应式阈值与频谱/Tray 视觉权重；布局测试同步读取该配置。
- **[Tray]**: 将托盘与 Power 收敛为低权重工业控件，同时保留溢出菜单和通知历史入口。
- **[设计]**: 更新稳定设计契约，统一石墨黑灰阶、冰蓝强调、3px 小圆角与响应式退让顺序。

### 修复
- **[控制中心]**: 系统占用读数改为等宽固定槽位居中；网络根据 NetworkManager 真实设备状态区分以太网与 Wi-Fi，改为打开/操作时刷新而非轮询；无蓝牙控制器时禁用蓝牙卡片；音量滑块改为可防止 Flickable 抢占的连续拖动，并通过去抖队列提交到 `wpctl`。
- **[通知]**: 修复分组模型刷新时的空值异常与布局锚点警告，并为通知分组显示发送应用图标，图标不可用时回退到应用首字母。
- **[Niri]**: 消除多屏重复事件流，补充真实 workspace 模型、输出过滤、断线重连与聚焦动作。
- **[Tray]**: 将应用图标恢复为 16px 标准 1× 显示，并在不改变托盘总宽度与响应式预算的前提下调整槽位间距。
- **[Bar]**: 将 Context、Clock 与 Metrics 顶部冰蓝校准线内缩至边框内侧，避免主题色线覆盖岛面外轮廓。
- **[Clock]**: 移除中央岛主题色横条，仅保留中性内高光和次级音量文字反馈。
- **[QML]**: 消除 `state` 属性覆盖和 Repeater 绑定作用域问题，恢复 Qt 6 静态检查与运行时稳定加载。
