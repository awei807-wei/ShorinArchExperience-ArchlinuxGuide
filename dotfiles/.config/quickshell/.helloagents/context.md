# 项目上下文

## 概述
这是 Arch Linux 桌面环境的 Quickshell 配置，提供顶部 Bar、右侧控制中心、通知历史、托盘交互和锁屏界面。主要面向当前 niri/Wayland 桌面会话，强调紧凑、稳定且可直接操作的系统状态界面。

## 技术栈
- QML / JavaScript，运行于 Quickshell 0.3.0 与 Qt 6。
- Quickshell 原生服务：PipeWire、MPRIS、Notifications、SystemTray 与进程/文件监听能力。
- 系统工具：`wpctl`、`brightnessctl`、`nmcli`、`bluetoothctl` 等。
- 验证以 `qmllint`、隔离 QML 检查入口、Python 单元测试和真实 Wayland 会话截图为主。

## 架构
- `shell.qml` 是生产入口，汇总系统服务、全局状态和控制动作。
- `Bar.qml` 与 `components/` 负责顶部 Bar、统一右侧双页面板、控制中心、通知与托盘等界面。
- `RightPanelController` 以可写 `rightPanelOpen/rightPanelPage/rightPanelProgress` 汇聚 Metrics/Tray 两个入口、触发屏幕、右岛起始/目标颈宽与固定外窗生命周期；仅触发屏幕的 `Bar`、`RightPanelHost` 和 `UnifiedRightPanel` 消费这一几何状态。面板 Canvas 始终保持最终几何，右锚定 reveal viewport 只做裁剪，Control / History 常驻并在壳内切页。
- `TrayNotificationModel.js` 是通知来源与当前 `SystemTray.items` 的统一身份匹配层；顶栏角标排序和 History 来源筛选共同使用 Desktop Entry、应用名、歧义保护与 QQ 特殊兜底。`NotificationLifecycleModel.js` 独立处理活动通知 identity 清理与替换分组。`SystemTrayModelBridge` 把稳定托盘模型的内容变化转换为 revision，驱动 History 重算来源顺序与菜单能力。
- `services/TopBarState.qml` 与上下文组件负责共享系统采集和桌面环境适配。
- 音频输出链路由 PipeWire 枚举/切换默认 sink，现有 `wpctl @DEFAULT_AUDIO_SINK@` 链路负责音量与静音。
- `lockscreen/` 是独立锁屏入口；`tests/` 是与生产配置隔离的视觉原型和布局门禁。

## 领域语言
- **右岛**：Bar 右侧的 System 区域；关闭态内容宽度约 `218–240px`，面板打开时轮廓通常扩成 `304px` 连接颈部，窄屏按时钟排除区收敛。Metrics 点击打开 Control，Tray 复合入口点击打开 History。
- **统一右侧子面板**：与右岛底边无缝连接、宽度限制 `560–640px`、承载 `CONTROL` 与 `HISTORY` 两页的唯一右侧详情窗口。两页共用 `760px` 目标高度，外窗固定；`300ms InOutCubic` 单进度同时驱动右岛与揭示区，前 `10%` 只展开右岛，面板从至少 `54px` 的安全视口淡入，内容从 `52%` 后进入。
- **音频输出设备**：PipeWire 中的硬件 sink；避免用语：MPRIS 播放器、应用音频流。
- **默认输出**：PipeWire 当前实际采用的 sink；**首选默认输出**：用户通过控制中心写入的 `preferredDefaultAudioSink`。
- **通知历史**：已持久化、可清理的通知记录；不同于当前临时通知浮层。
- **通知来源**：以规范化 `desktopEntry` / `appName` 别名聚合的历史应用分组；多个分组匹配同一活跃托盘项时再次合并。全部活跃托盘项无条件进入筛选栏并按历史通知数稳定升序，同数保持注册顺序；普通历史来源位于托盘区之后并按最近通知排序。

## 目录结构
- `shell.qml`、`Bar.qml`：生产入口与顶部 Bar 编排。
- `components/`：控制中心、托盘、通知、上下文和基础控件。
- `config/`：主题与像素微调参数。
- `services/`：跨组件共享的系统状态。
- `lockscreen/`：独立锁屏界面和检查入口。
- `tests/`：隔离视觉原型与布局门禁。
- `.helloagents/`：设计契约、模块知识、验证命令和方案归档。

## 模块文档
- [Bar](modules/bar.md)
- [控制中心音频](modules/control-center-audio.md)
- [锁屏](modules/lockscreen.md)

## 最近变更
见 [CHANGELOG.md](CHANGELOG.md)
