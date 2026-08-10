# 控制中心音频输出设备选择 — 任务分解

## 拆分原则
- 默认按端到端垂直切片拆分：每个任务交付一个可验证行为，而不是单独交付某一层。
- `AFK` 表示代理可独立完成；`HITL` 表示需要用户决策、外部凭据、人工视觉确认或手动验收。
- 厚任务必须继续拆小；横向前置任务只在确有技术依赖时保留。

## 任务列表
- [√] 任务1（AFK）：建立 PipeWire 输出设备模型与默认输出切换接口（依赖：无；涉及文件：`components/AudioOutputModel.js`、`shell.qml`、`audio-output-model-check.qml`；预期变更：过滤并稳定展示硬件 sink，支持写入 preferred default；完成标准：模型检查通过且 shell 静态加载无新增错误；验证方式：`quickshell --no-color -p audio-output-model-check.qml`、运行时加载日志）。
- [√] 任务2（AFK）：在音量栏加入符合现有设计系统的下拉选择（依赖：任务1；涉及文件：`components/ControlCenterSlider.qml`、`components/ControlCenterOutputSelector.qml`、`components/ControlCenterOutputList.qml`、`components/ImportedControlCenterPanel.qml`；预期变更：紧凑展开按钮、卡片内设备列表、当前设备绑定、空/禁用/焦点/长文本状态；完成标准：亮度滑条不变，音量栏可选择设备且布局稳定；验证方式：`qmllint`、隔离交互检查与控制中心运行时截图）。
- [√] 任务3（AFK）：执行回归门禁并同步知识库（依赖：任务1、任务2；涉及文件：`.helloagents/context.md`、`.helloagents/guidelines.md`、`.helloagents/verify.yaml`、`.helloagents/modules/control-center-audio.md`、`.helloagents/DESIGN.md`、`.helloagents/CHANGELOG.md`；预期变更：记录数据流、UI 契约、验证命令与结果；完成标准：相关自动化门禁通过且文档与代码一致；验证方式：验证清单与 `git diff --check`）。
- [-] 任务4（HITL）：真实多音频设备切换验收（依赖：任务1、任务2；涉及文件：无；预期变更：无；完成标准：在至少两个真实 sink 间切换后，默认输出、滑条与静音均跟随；验证方式：用户会话中的控制中心交互与 `wpctl get-volume @DEFAULT_AUDIO_SINK@`）。本轮已完成真实双设备枚举、选择信号写入和视觉验收；为避免打断当前播放，未自动切到另一物理设备再切回。

## Codex /goal 执行入口
不使用外层 `/goal`；本轮直接执行全部 AFK 任务，HITL 仅在无法通过当前用户会话自动验证时保留。

## 进度
AFK 任务 3/3 完成，HITL 跨设备音频播放切换按用户确认收尾并跳过破坏当前播放的自动改切；实现、视觉与回归验证完成。
