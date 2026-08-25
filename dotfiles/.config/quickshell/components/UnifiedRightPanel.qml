import "../config" as Config
import QtQuick

// 固定尺寸外层中的右面板。外壳始终按最终几何绘制，右锚定 viewport
// 只负责揭示；Bar、viewport 和输入区域共同消费 Controller 的单一进度。
Item {
    id: root

    required property var shellRoot
    required property var store
    property var menuWindow: null
    property var trayItems: []
    property int trayModelRevision: 0

    property bool open: false
    property int page: 0
    property bool reducedMotion: false

    property real shellProgress: open ? 1 : 0
    property real baseRightWidth: Config.BarTuning.rightPanelNeckWidth
    property real targetRightWidth: Config.BarTuning.rightPanelNeckWidth

    readonly property real normalizedBaseRightWidth: Math.max(
        1, Math.min(Config.BarTuning.rightPanelNeckWidth,
                    baseRightWidth)
    )
    readonly property real collapsedWidth: Math.min(
        width,
        normalizedBaseRightWidth + Config.BarTuning.rightPanelFlare
    )
    readonly property real normalizedTargetRightWidth: Math.max(
        normalizedBaseRightWidth,
        Math.min(width, Config.BarTuning.rightPanelNeckWidth,
                 targetRightWidth)
    )
    readonly property real openHeight: height
    readonly property real normalizedShellProgress:
        clamp01(shellProgress)
    readonly property real currentNeckWidth: Math.round(
        normalizedBaseRightWidth
        + (normalizedTargetRightWidth
            - normalizedBaseRightWidth) * normalizedShellProgress
    )
    readonly property real shellHorizontalOffset:
        normalizedTargetRightWidth - currentNeckWidth
    readonly property real bodyProgress: stagedProgress(
        normalizedShellProgress,
        Config.BarTuning.panelBodyStartProgress
    )
    readonly property real contentProgress: stagedProgress(
        normalizedShellProgress,
        Config.BarTuning.panelContentStartProgress
    )
    readonly property real safeRevealHeight: Math.min(
        openHeight,
        Config.BarTuning.rightPanelFlare
            + Config.BarTuning.rightPanelRadius * 2
            + Config.BarTuning.panelSafeRevealExtra
    )

    readonly property Item inputRegion: inputMask
    readonly property Item sizerItem: sizer
    readonly property Item shapeItem: panelShape
    readonly property real controlPageOpacity:
        controlsPageWrapper.opacity
    readonly property real historyPageOpacity:
        historyPageWrapper.opacity
    readonly property real controlPageX: controlsPageWrapper.cardX
    readonly property real historyPageX: historyPageWrapper.cardX
    readonly property real controlPageScale:
        controlsPageWrapper.cardScale
    readonly property real historyPageScale:
        historyPageWrapper.cardScale
    readonly property bool controlPageReady:
        controlsPageWrapper.contentReady
    readonly property bool historyPageReady:
        historyPageWrapper.contentReady
    readonly property bool controlBaseContentFits:
        controlPanel.baseContentFits

    signal closeRequested()
    signal pageRequested(int page)

    focus: open

    function clamp01(value) {
        return Math.max(0, Math.min(1, value))
    }

    function stagedProgress(value, startProgress) {
        const start = clamp01(startProgress)
        if (start >= 1)
            return value >= 1 ? 1 : 0
        return clamp01((value - start) / (1 - start))
    }

    onOpenChanged: {
        if (open)
            Qt.callLater(forceActiveFocus)
    }

    Keys.onEscapePressed: closeRequested()

    Item {
        id: inputMask

        x: sizer.x
        y: Config.BarTuning.rightPanelFlare
        width: sizer.width
        height: root.bodyProgress > 0.001
            ? Math.max(0, sizer.height
                - Config.BarTuning.rightPanelFlare)
            : 0
    }

    Item {
        id: sizer

        anchors.top: parent.top
        anchors.right: parent.right
        width: Math.round(root.collapsedWidth
            + (root.width - root.collapsedWidth)
                * root.normalizedShellProgress)
        height: Math.round(root.safeRevealHeight
            + (root.openHeight - root.safeRevealHeight)
                * root.bodyProgress)
        opacity: root.bodyProgress
        clip: true

        // 面板内部空白由此层消费，外部点击只落到宿主的关闭层。
        MouseArea {
            anchors.fill: parent
            enabled: root.bodyProgress > 0.001
        }

        // 轮廓永远保持最终宽高；动画只改变外层 viewport，不再把凹角、
        // 主体圆角和底部圆角压入无法成立的 16–52px 中间高度。
        Item {
            id: fixedShell

            anchors.top: parent.top
            anchors.right: parent.right
            width: root.width
            height: root.openHeight

            RightPanelShape {
                id: panelShape

                anchors.fill: parent
                transform: Translate {
                    x: root.shellHorizontalOffset
                }
                neckWidth: root.normalizedTargetRightWidth
                bodyWidth: root.width
                radius: Config.BarTuning.rightPanelRadius
                flare: Config.BarTuning.rightPanelFlare
                color: Config.Theme.surface
            }

            // 页面始终按最终宽高排版，内容进度仅控制透明度和轻位移。
            Item {
                id: contentStage

                anchors.fill: parent
                opacity: root.contentProgress
                enabled: root.contentProgress > 0.95
                visible: root.contentProgress > 0.001
                transform: Translate {
                    y: 8 * (1 - root.contentProgress)
                }

                Item {
                    id: pageArea

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: pageSwitcher.top
                    anchors.topMargin: Config.BarTuning.rightPanelFlare
                        + Config.BarTuning.rightPanelPaddingTop
                    clip: true

                    AnimatedPanelPage {
                        id: controlsPageWrapper

                        anchors.fill: parent
                        anchors.leftMargin:
                            Config.BarTuning.rightPanelPaddingH
                        anchors.rightMargin:
                            Config.BarTuning.rightPanelPaddingH
                        active: root.page === 0
                        reducedMotion: root.reducedMotion
                        inactiveX:
                            -Config.BarTuning.panelPageCardOffset

                        ImportedControlCenterPanel {
                            id: controlPanel

                            anchors.fill: parent
                            shellRoot: root.shellRoot
                            embedded: true
                            open: root.open && root.page === 0
                            visible: true
                            reducedMotion: root.reducedMotion
                            backgroundColor: "transparent"
                            surfaceColor: Config.Theme.surfaceContainer
                            elevatedColor: Config.Theme.outline
                            borderColor: Config.Theme.outline
                            textColor: Config.Theme.textPrimary
                            mutedColor: Config.Theme.textMuted
                            accentColor: Config.Theme.accent
                            dangerColor: Config.Theme.danger
                        }
                    }

                    AnimatedPanelPage {
                        id: historyPageWrapper

                        anchors.fill: parent
                        active: root.page === 1
                        reducedMotion: root.reducedMotion
                        inactiveX:
                            Config.BarTuning.panelPageCardOffset

                        NotificationHistoryPage {
                            id: historyPage

                            anchors.fill: parent
                            store: root.store
                            menuWindow: root.menuWindow
                            trayItems: root.trayItems
                            trayModelRevision: root.trayModelRevision
                            embedded: true
                            open: root.open && root.page === 1
                            visible: true
                            reducedMotion: root.reducedMotion
                            panelWidth: root.width
                            zenInk: "transparent"
                            zenStone: Config.Theme.surfaceContainer
                            zenMist: Config.Theme.outline
                            zenAsh: Config.Theme.outlineVariant
                            zenSmoke: Config.Theme.textMuted
                            zenCloud: Config.Theme.textSecondary
                            zenSnow: Config.Theme.textPrimary
                            zenAccent: Config.Theme.accent
                            zenDanger: Config.Theme.danger
                            onCloseRequested: root.closeRequested()
                        }
                    }
                }

                RightPanelPageSwitcher {
                    id: pageSwitcher

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Config.BarTuning.rightPanelPaddingH
                    anchors.rightMargin: Config.BarTuning.rightPanelPaddingH
                    height: Config.BarTuning.rightPanelFooterHeight
                    currentPage: root.page
                    reducedMotion: root.reducedMotion
                    onPageRequested: targetPage =>
                        root.pageRequested(targetPage)
                }
            }
        }
    }
}
