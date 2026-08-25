# 右侧双页子面板 — 实施规划

## 本地架构映射
- `config/BarTuning.qml`：规格中的 Metrics，集中保存几何、页面与动画参数。
- `components/RightPanelController.qml`：规格中的 Popups，统一管理打开、页面与外窗生命周期。
- `Bar.qml` / `components/BarContour.qml`：规格中的 TopBar，只改变右岛轮廓宽度。
- `components/RightPanelHost.qml`：固定最大透明外窗、定位、外部单击和动态 mask。
- `components/UnifiedRightPanel.qml`：内部 sizer、分阶段开关动画、页面高度与内容编排。
- `components/RightPanelShape.qml`：连接颈部和主体轮廓。
- `components/RightPanelTabs.qml`、`components/AnimatedPanelPage.qml`：紧凑分页与常驻页面过渡。
- `components/NotificationHistoryPage.qml`：内容驱动的通知历史页。

## 实施顺序
1. 集中参数并升级单一状态机。
2. 固定外窗最大尺寸，建立右锚定 sizer 和跟随其尺寸的输入区域。
3. 实现 neck、body、flare 分离的轮廓。
4. 让 Bar 轮廓在打开时扩张到 304px，关闭壳体开始收起后再缩回。
5. 用 `widthProgress/heightProgress/contentProgress` 实现可中途反向的开关动画。
6. 将 Control 与 History 保持常驻，接入交叉淡入、12px 位移和高度动画。
7. 换成单一滑动指示器的紧凑分页条。
8. 重排通知层级，按列表内容计算 History 高度并限制滚动。
9. 执行静态、状态、快速反向、快速切页、输入 mask 和实屏验证。

## 性能策略
- PopupWindow 与宿主窗口不改变尺寸或锚点，Wayland 表面无需逐帧重建。
- 开合只改变轻量 sizer 的裁剪尺寸；`RightPanelShape` 始终按最终几何绘制，不随宽高进度逐帧重绘。
- 内容只使用 `opacity + y`，避免文本缩放模糊。
- 页面切换不改变 `open/windowVisible`，避免重复加载和开关动画。
- Canvas 路径保持简单，仅在最终几何、页面目标高度或颜色变化时显式重绘。

## 状态机
- 关闭 + 任一入口：记录目标页，立即显示外窗，从当前进度打开。
- 打开 + 同入口：从当前进度关闭。
- 打开 + 另一入口：只切页和目标高度。
- 关闭中 + 任一入口：停止关闭动画，从当前进度反向打开。
- 打开中 + 同入口、外部或 Escape：停止打开动画，从当前进度反向关闭。
- 收起完成才隐藏外窗；页面值不重置。

## 风险控制
- 多屏宿主的退场完成回报必须忽略重新打开后的过期信号。
- History 内容高度异步变化只更新目标高度，不重播开启动画。
- 打开期间输入 mask 覆盖外部点击区；关闭开始后立即缩到 sizer。
- Bar 右岛视觉颈部与实际内容宽度分离，不能裁掉状态与 Tray 点击区。
- 面板宿主虽上移一个 flare，但只允许颈部边界左右各 `16px` 的连接区进入 Bar：左侧绘制反 R 弧，右侧抹平右岛旧外凸角；禁止重复填充整块颈部并覆盖内容。

## 已冻结决策
- 用户确认当前单窗口外部点击一次关闭有效，保留该输入模型。
- 最终规格覆盖旧的 320ms 宽高同步展开，改为 40/95/180ms 分段起始。
- 右岛是 304px 连接颈部，面板主体宽度独立为 560–640px。
- 页面切换不得关闭或重新打开面板。
- History 打开不再触发 Tray 全量图标展开；右岛内容始终保持紧凑并限制在颈部范围内。
