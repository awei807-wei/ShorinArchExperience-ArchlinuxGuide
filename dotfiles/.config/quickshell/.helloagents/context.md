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
- `RightPanelController` 以可写 `rightPanelOpen/rightPanelPage` 汇聚 Metrics/Tray 两个入口的打开、关闭和页面状态；`RightPanelHost` 使用固定最大窗口与动态输入区，`UnifiedRightPanel` 通过内部 sizer 裁剪最终外壳、分阶段展开并常驻 Control / History 页面。
- `services/TopBarState.qml` 与上下文组件负责共享系统采集和桌面环境适配。
- 音频输出链路由 PipeWire 枚举/切换默认 sink，现有 `wpctl @DEFAULT_AUDIO_SINK@` 链路负责音量与静音。
- `lockscreen/` 是独立锁屏入口；`tests/` 是与生产配置隔离的视觉原型和布局门禁。

## 领域语言
- **右岛**：Bar 右侧的 System 区域；关闭态内容宽度约 `218–240px`，面板打开时轮廓扩成 `304px` 连接颈部。Metrics 点击打开 Control，Tray 复合入口点击打开 History。
- **统一右侧子面板**：与右岛底边无缝连接、宽度限制 `560–640px`、承载 `CONTROL` 与 `HISTORY` 两页的唯一右侧详情窗口。外窗固定，内部面板先向左、再向下生长，内容最后进入。
- **音频输出设备**：PipeWire 中的硬件 sink；避免用语：MPRIS 播放器、应用音频流。
- **默认输出**：PipeWire 当前实际采用的 sink；**首选默认输出**：用户通过控制中心写入的 `preferredDefaultAudioSink`。
- **通知历史**：已持久化、可清理的通知记录；不同于当前临时通知浮层。

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
