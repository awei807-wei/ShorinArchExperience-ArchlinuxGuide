# 控制中心音频输出设备选择 — 实施规划

## 目标与范围
在现有右侧控制中心音量栏中加入输出设备下拉选择。设备模型来自 Quickshell 原生 PipeWire 服务，选择动作只修改首选默认输出；现有 `@DEFAULT_AUDIO_SINK@` 音量/静音链路保持不变并自动跟随新默认设备。

## 架构与实现策略
- 新增纯 JavaScript 音频输出模型辅助模块，集中完成硬件 sink 过滤、稳定排序、显示名回退、重复名称消歧和当前索引匹配，避免把非 UI 逻辑堆入 `shell.qml`。
- `shell.qml` 负责把 `Pipewire.nodes.values` 映射为可供 UI 使用的选项，并通过 `Pipewire.preferredDefaultAudioSink` 执行切换；默认 sink 短暂为空时使用 preferred sink 保持选中状态稳定。
- `ControlCenterSlider.qml` 增加仅显示下拉箭头的紧凑展开按钮，仅音量实例启用；点击后音量卡片自身增高，并在同一卡片下半区呈现设备列表，亮度实例保持原样。
- `ImportedControlCenterPanel.qml` 只负责绑定选项、当前索引、占位文本与选择信号。

## 领域语言
- **音频输出设备**：PipeWire 中 `isSink=true`、`isStream=false` 且具备 `audio` 信息的硬件输出节点；避免使用“播放器”指代 MPRIS 应用。
- **默认输出**：`Pipewire.defaultAudioSink` 当前实际采用的输出；**首选默认输出**：写入 `Pipewire.preferredDefaultAudioSink` 的用户选择。

## 完成定义
- 音量栏在多设备环境显示下拉选项，当前项与 PipeWire 默认输出一致。
- 选择设备后写入 `preferredDefaultAudioSink`，随后刷新默认 sink 音量状态。
- 启动同步期间、零设备和默认 sink 短暂为空时无异常或空白控件。
- 设备名称按 nickname → description → name → id 回退，重复名称可区分。
- `qaMode=standard`；重点检查 QML 绑定稳定性、PipeWire 节点过滤、ComboBox 弹出层交互和原有滑条回归。

## 文件结构
- `components/AudioOutputModel.js`：纯设备模型逻辑。
- `components/ControlCenterSlider.qml`：可选输出设备下拉附件。
- `components/ImportedControlCenterPanel.qml`：音量栏绑定。
- `shell.qml`：PipeWire 数据与切换接口。
- `audio-output-model-check.qml`：纯模型自动化检查。
- `.helloagents/`：设计契约、模块知识、验证命令、变更日志与方案归档。

## UI / 设计约束
- 本次属于既有风格的演进式优化，不改变控制中心视觉方向。
- 音量栏内只显示 34px 下拉按钮，位于滑条与百分比之间；设备名称只在下方选项浮层和悬浮提示中显示，不压缩主滑条。
- 设备列表不得覆盖亮度栏或使用独立浮层；音量卡片通过布局高度动画向下展开，后续内容随之下移。
- 选择任一设备后，设备区域收起并恢复原始 62px 音量卡片高度。
- 表面、边框、文字、强调色和动画时长复用现有 token；禁止默认 Qt Controls 外观、胶囊化和额外强调色。
- 覆盖 hover、pressed、focus、disabled、empty 与 popup open 状态；支持键盘和减弱动效偏好。

## 风险与验证
- PipeWire 默认 sink 在切换时可能短暂为 `null`：选中索引同时参考 preferred sink。
- 未绑定 PwNode 的扩展属性不可依赖：仅使用官方文档明确可用于筛选/展示的基础节点字段。
- 设备区域可能在 Flickable 内被裁剪：让音量卡片通过布局高度展开并进行实机/截图验收，禁止使用覆盖后续卡片的独立浮层。
- 沙箱可能无法连接用户 PipeWire/Wayland 会话：先完成静态与隔离门禁，必要时以受控的用户会话命令验证。

## 决策记录
- [2026-08-10] 将“设备作为播放器”解释为选择音频输出 sink，而不是选择 MPRIS 播放器应用；依据是需求明确使用“设备”并附着于音量栏。
- [2026-08-10] 采用 Quickshell 0.3.0 原生 PipeWire 服务枚举与切换，避免解析 `wpctl status` 的本地化文本。
- [2026-08-10] 保留现有 `wpctl @DEFAULT_AUDIO_SINK@` 音量链路，以最小范围获得切换后的自动跟随。
