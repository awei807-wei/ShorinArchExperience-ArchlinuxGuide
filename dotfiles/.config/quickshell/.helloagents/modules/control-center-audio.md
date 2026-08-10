# 模块: 控制中心音频

## 用途
在右岛控制中心中展示默认输出音量，并允许用户在同一音量卡片内选择 PipeWire 音频输出设备。

## 关键文件
- `shell.qml`：读取 PipeWire 节点、计算当前输出并写入 `preferredDefaultAudioSink`；保留既有 `wpctl @DEFAULT_AUDIO_SINK@` 音量与静音链路。
- `components/AudioOutputModel.js`：过滤硬件 sink、稳定排序、标签回退、重复名称消歧和当前索引计算。
- `components/ImportedControlCenterPanel.qml`：把全局音频状态绑定到音量栏。
- `components/ControlCenterSlider.qml`：音量卡片展开/收起、滑条布局和选择信号。
- `components/ControlCenterOutputSelector.qml`：滑条与百分比之间的紧凑展开按钮。
- `components/ControlCenterOutputList.qml`：卡片内部的居中设备候选列表和当前项标记。
- `audio-output-model-check.qml`、`audio-output-selector-check.qml`：模型与展开交互的隔离门禁。

## 依赖
- `Quickshell.Services.Pipewire` 提供节点集合、当前默认 sink 和首选默认 sink。
- `wpctl` 继续负责默认 sink 的音量读取、设置和静音，切换默认输出后无需重建原有链路。
- 控件颜色、圆角、字号和动画时长来自 `config/Theme.qml`。

## 经验
- 只保留 `audio` 存在、`isSink=true`、`isStream=false` 的节点，避免把麦克风或应用流展示为输出设备。
- 显示名按 `nickname → description → name → id` 回退；重复名称附加节点名，避免不可区分选项。
- 默认 sink 在切换时可能短暂为空，当前选择同时参考 `preferredDefaultAudioSink`。
- 设备列表必须在音量卡片内部向下展开并推动后续卡片，不使用覆盖亮度栏的浮层；选择后立即收起。
- 候选文字以整行水平中心为基准，当前项勾选独立贴右，不参与文字居中计算。
