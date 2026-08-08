# 模块: 独立锁屏

## 用途
提供由 niri 快捷键调起的独立 Quickshell 锁屏窗口，包含 Wayland 锁定层、PAM 密码认证、动态壁纸与右上角电源/idle 控制。

## 关键文件
- `lockscreen/shell.qml`：锁定层、PAM 生命周期、认证输入与系统命令桥接；本轮保留其超过 400 行的历史债务，仅抽取右上角控件以降低改动风险。
- `lockscreen/PowerControls.qml`：右上角两个等尺寸圆形 hit target、电源菜单布局与输入信号；不直接执行 `systemctl` 或 idle-control。
- `lockscreen/power-controls-check.qml`：离屏布局门禁，验证按钮几何中心、图标字体/对齐、菜单上下/右侧锚定稳定性，并确认组件构造不触发系统副作用。
- `scripts/lockscreen.sh`：锁屏入口脚本；idle-control 的锁定/息屏策略由 `scripts/idle-control.sh` 管理。

## 视觉与布局契约
- 电源与 idle 按钮共享 `2.8u` 直径、同一 Row 垂直中心线和 `0.55u` 间距；菜单固定锚定在按钮组下方 `0.75u`，并保持右侧对齐。
- 图标统一使用已安装的 `JetBrainsMono Nerd Font`：power `U+F011`，idle 开启/关闭分别为 `U+F070` / `U+F06E`。Text 使用 `anchors.fill`、`AlignHCenter` 与 `AlignVCenter`，避免 emoji/color-font fallback 导致行框和墨迹中心漂移。
- idle 开启时继续显示带斜线 glyph，保留原有状态语义；系统命令和 PAM 安全链路不由控件组件持有。

## 验证
- `env QUICKSHELL_TEST_MODE=1 quickshell --no-color -p lockscreen/power-controls-check.qml`
- `qmllint lockscreen/shell.qml lockscreen/PowerControls.qml lockscreen/power-controls-check.qml`
- `git diff --check`

## 经验
- [2026-08-08] 右上角控件原先使用未指定字体的 `⏻` / `👁`，会分别落入不同字体 fallback；在固定 hit target 内改用 Nerd Font glyph 并让 Text 填满按钮后，几何中心和视觉墨迹中心稳定，避免无依据的 optical offset。
- [2026-08-08] `PowerControls` 只发出菜单、idle 与电源动作信号，`shell.qml` 继续负责 `powerMenuVisible`、PAM、`idle-control.sh` 和 `systemctl`，便于离屏测试而不触发真实锁屏或电源副作用。
