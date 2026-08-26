# 锁屏认证与操作控件重构 — 实施规划

## 目标与范围
修复聚焦状态下密码提示消失的真实可用性缺陷，并把认证区和右上角操作区统一为清晰、紧凑、可测试的桌面锁屏控件；验收以确定性几何、完整状态反馈和无字体图标残留为准。

## 架构与实现策略
- 新建 `LockscreenAuth.qml`，封装身份行、凭据框、内嵌提交按钮、固定状态槽与错误动画；通过属性和信号接入现有 PAM 控制器。
- 新建 `LockGlyph.qml`，在归一化方形坐标中绘制 power / eye / eye-off，避免字体排版框、baseline 和 fallback 差异。
- 重构 `PowerControls.qml` 为 `96×44` 操作胶囊，保留既有动作信号与菜单锚定语义；菜单采用纯文字动作。
- `shell.qml` 只负责同步用户、PAM 状态和系统动作：用户名优先同步读取环境变量，`whoami` 仅在空值时兜底。
- 测试直接实例化无副作用组件，不实例化 `WlSessionLock`。

## 领域语言
- “凭据框”：密码输入与内嵌解锁按钮组成的单一认证控件。
- “操作胶囊”：右上角承载电源菜单入口与 idle 开关的统一容器。
- “字体图标”：以 `Text` 字形呈现图标的旧实现；本次全部移除。

## 完成定义
- `qaMode=deep`；重点检查 PAM 边界未变、组件构造无系统副作用、空密码聚焦提示、busy 禁用、状态高度与矢量中心。
- 源码不再含 Nerd Font 锁屏图标码点或电源菜单 Unicode 图标字段。
- 自动测试、QML lint、差异检查通过；无法安全启动真实 `WlSessionLock` 的限制以隔离视觉与几何证据替代并明确记录。

## 文件结构
- 新增：`lockscreen/LockGlyph.qml`、`lockscreen/LockscreenAuth.qml`、`lockscreen/lockscreen-auth-layout-check.qml`。
- 修改：`lockscreen/PowerControls.qml`、`lockscreen/power-controls-check.qml`、`lockscreen/shell.qml`。
- 同步：`.helloagents/DESIGN.md`、`.helloagents/modules/lockscreen.md`、`.helloagents/verify.yaml`、`.helloagents/CHANGELOG.md`。
- 归档：`.helloagents/archive/2026-08/202608261343_lockscreen_auth_controls/` 与归档索引。

## UI / 设计约束
- 目的：让桌面用户在锁定瞬间确认身份、理解输入位置并快速提交；主要视口为当前 Wayland 桌面锁屏。
- 情绪方向：安静、精确、可信；延续动态暗色表面与主题强调色，不复制 Bar 的几何，也不引入新视觉语言。
- 记忆点：一个完整凭据框与一个确定性矢量操作胶囊，替代漂浮色板和字体墨迹。
- token：颜色继续由 `shell.qml` / `Config.Theme` 注入；组件内部只固定用户已确认的 `360/54/48/44/22px` 几何、字体角色与快速动效时长。
- 状态矩阵：空值显示提示；输入中保持焦点；busy 禁用并显示 spinner/状态；失败显示错误色和水平抖动；减弱动效时立即切换且不抖动。
- 适配：认证宽度固定为 `360px` 并在全屏中心布局；右上角距顶 `20px`、距右 `24px`；不改变屏幕级安全边界。

## 风险与验证
- 风险：组件抽取可能破坏 `passwordText` 双向同步或错误后的焦点恢复；通过公开方法和信号边界测试、shell lint 与静态调用审计验证。
- 风险：Canvas 首帧或颜色变化未重绘；覆盖完成、尺寸、名称和颜色变更的 `requestPaint()` 路径。
- 风险：真实锁屏不可在自动回归中安全启动；以隔离组件 offscreen 测试和预览截图验证，不触发 `WlSessionLock`。
- 回退点：系统动作和 PAM 控制器保持原文件、原信号语义，不与表现组件耦合。

## 决策记录
- [2026-08-26] 用户已给出明确终局与尺寸，直接冻结为单一实施方案，不再保留 Nerd Font 或光学偏移兼容路径。
- [2026-08-26] 为使认证布局可安全测试，抽出专用 `LockscreenAuth`，不让检查入口加载完整锁屏。
