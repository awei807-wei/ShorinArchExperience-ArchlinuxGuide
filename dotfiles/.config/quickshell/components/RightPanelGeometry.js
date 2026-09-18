.pragma library

// 右侧子面板的最终几何。RightPanelHost（面板窗口）与 PanelOutsideClickCatcher
// （外部点击捕获窗口的输入区域扣除）共用同一套计算，避免两处漂移。

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value))
}

/** 面板主体宽度：按屏宽比例计算，并限制在 tuning 的最小/最大宽度内。 */
function panelWidth(screenWidth, tuning) {
    return clamp(
        Math.round(screenWidth * tuning.rightPanelWidthRatio),
        Math.min(tuning.rightPanelWidthMin, screenWidth),
        Math.min(tuning.rightPanelWidthMax, screenWidth)
    )
}

/** 面板窗口高度（含顶部 flare）：目标高度受屏幕可用高度统一限制。 */
function panelContentHeight(screenHeight, panelTop, barBottom, tuning) {
    const minimumPanelHeight = tuning.rightPanelFlare
        + tuning.rightPanelRadius * 2
        + tuning.panelSafeRevealExtra
    const surfaceHeight = Math.max(0, screenHeight - panelTop)
    const availablePanelHeight = Math.max(
        Math.min(minimumPanelHeight, surfaceHeight),
        Math.min(surfaceHeight, screenHeight - barBottom - 24)
    )
    return Math.min(tuning.rightPanelHeight, availablePanelHeight)
}
