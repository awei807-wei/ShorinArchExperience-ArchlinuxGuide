# Edge-Integrated Contoured Bar 预览

这是与生产 `Bar.qml` 完全隔离的视觉原型，使用固定 mock 数据，不读取 Niri、托盘、通知或系统指标服务。

## 启动

在有 Wayland 会话的环境中运行：

```bash
quickshell -p tests/
```

目录启动方式会自动加载 `tests/shell.qml`，它是指向预览入口的相对符号链接。也可直接指定入口文件：

```bash
quickshell -p tests/edge-integrated-preview.qml
```

退出：在终端按 `Ctrl+C`（只结束该测试预览进程，不触碰正在运行的生产 QuickShell）。

预览入口使用 `PanelWindow` 贴合当前屏幕顶部，并通过 `exclusionMode: ExclusionMode.Ignore` 与 Wayland `Overlay` layer 置于顶层；窗口高度为 88px，exclusive zone 为 0，不占用布局保留区，也不修改生产配置。由于 rail 下方舱间刻意保持透明，干净预览请在生产 Bar 未运行的独立会话中启动；若两者同时运行，透明空档会看到旧 Bar 内容。按 `Ctrl+C` 只结束测试预览进程。

预览支持 2048、1600、1280 与 800 宽度；800px 是当前最低支持宽度，低于该宽度不保证内容完整展示（不连接生产 Bar，也不会改动现有配置）。

## 验证

```bash
qmllint tests/*.qml
QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic \
  tests/run-layout-check.sh
```

布局检查覆盖 2048、1600、1280、800 宽度，并验证左右边界、主舱之间至少 10px 安全间距，以及右侧 Metrics、Tray、Power 独立舱的内容不溢出。

## 文件结构

- `edge-integrated-preview.qml`：隔离预览入口，仅负责 `ShellRoot`、屏幕遍历和 `PanelWindow`。
- `shell.qml`：目录启动兼容入口，指向 `edge-integrated-preview.qml`。
- `EdgeIntegratedBar.qml`：连续 rail 与三舱的响应式定位编排。
- `ContourPod.qml`：顶部平直、底部圆角的共用舱体轮廓和阴影。
- `WorkspacePod.qml`：工作区范围与 01–05 工作区选择器。
- `ClockPod.qml`：时间、日期与星期信息。
- `SystemPod.qml`：右侧系统集群编排，包含独立的 Metrics、Tray、Power 三个下伸轮廓舱。
- `UtilityIcon.qml`：Discord、Telegram、邮件的隔离矢量图标。
- `edge-integrated-layout-check.qml`：无窗口布局断言，供离屏检查使用。
- `run-layout-check.sh`：等待 `PASS` 并传递检查退出状态的包装脚本。

所有文件均位于 `tests/`，不会被生产 `Bar.qml` 加载，也不会连接 Niri、托盘或系统服务；预览仅在运行期间显示，不改动生产配置。
