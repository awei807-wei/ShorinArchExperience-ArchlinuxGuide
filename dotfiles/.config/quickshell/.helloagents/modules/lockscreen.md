# 模块: 独立锁屏

## 用途
提供由 niri 快捷键调起的独立 Quickshell 锁屏窗口，包含 Wayland 锁定层、PAM 密码认证、动态壁纸与右上角电源/idle 控制。

## 关键文件
- `lockscreen/shell.qml`：锁定层、PAM 生命周期、动态背景与系统命令桥接；认证表现已抽离，历史背景/进程职责仍待后续按独立需求拆分。
- `lockscreen/LockscreenAuth.qml`：横向身份行、一体化凭据框、固定状态槽、busy spinner 与错误水平抖动；通过信号和公开方法接入 shell，不直接持有 PAM。
- `lockscreen/LockGlyph.qml`：以归一化 Canvas 坐标绘制 power / eye / eye-off，不依赖字体 baseline、fallback 或字形留白。
- `lockscreen/PowerControls.qml`：右上角统一操作胶囊、纯文字电源菜单与输入信号；不直接执行 `systemctl` 或 idle-control。
- `lockscreen/power-controls-check.qml`：离屏验证操作胶囊、点击区、矢量图标名称/尺寸/几何中心、idle 状态与菜单锚定。
- `lockscreen/lockscreen-auth-layout-check.qml`：离屏验证聚焦空输入提示、内嵌按钮边界、固定状态槽、PAM busy 禁用、错误高度稳定与无构造副作用。
- `scripts/lockscreen.sh`：锁屏入口脚本；idle-control 的锁定/息屏策略由 `scripts/idle-control.sh` 管理。

## 视觉与布局契约
- 认证组件固定宽 `360px`：身份块 `48px`、凭据框 `360×54px` / 圆角 `16px`、内嵌按钮 `92×40px` / 圆角 `12px`、状态槽 `22px`。
- 空密码无论焦点状态都显示提示；PAM 活跃时提示隐藏、输入与提交禁用，状态槽继续显示验证信息且布局高度不变。
- 错误反馈只水平移动完整凭据框，减弱动效时不移动；按钮不再独立成块或旋转。
- 操作胶囊固定 `96×44px`，两个 `42×40px` 点击区内分别居中 `18px` Canvas 图标；idle 开启显示 `eye-off`，关闭显示主题强调色 `eye`。
- 锁屏不使用字体字符图标；小型电源菜单采用纯文字。系统命令和 PAM 安全链路不由表现组件持有。

## 验证
- `QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic quickshell --no-color -p lockscreen/power-controls-check.qml`
- `QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic quickshell --no-color -p lockscreen/lockscreen-auth-layout-check.qml`
- `qmllint -I /usr/lib/qt6/qml` 分别检查 `LockGlyph.qml`、`LockscreenAuth.qml`、`PowerControls.qml`、`shell.qml` 与两个检查入口。
- `git diff --check`

## 经验
- [2026-08-08] `PowerControls` 只发出菜单、idle 与电源动作信号，`shell.qml` 继续负责 `powerMenuVisible`、PAM、`idle-control.sh` 和 `systemctl`，便于离屏测试而不触发真实锁屏或电源副作用。
- [2026-08-26] 字体排版框居中不能保证图标墨迹重心一致；锁屏操作图标改为固定坐标 Canvas 后，测试应验证图标种类、尺寸和几何中心，不再锁定字体、码点或 Text 对齐属性。
- [2026-08-26] 认证布局测试必须实例化无副作用的 `LockscreenAuth`，不能为了检查焦点和几何而加载会真实锁定会话的 `WlSessionLock`。
