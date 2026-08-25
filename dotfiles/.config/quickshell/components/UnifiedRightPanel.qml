import "../config" as Config
import QtQuick

// 固定尺寸外层中的可变形右面板。宽度、高度和内容各有独立进度，
// 因而快速反向时从当前值继续，不会跳到完整展开态再收回。
Item {
    id: root

    required property var shellRoot
    required property var store

    property bool open: false
    property int page: 0
    property bool reducedMotion: false

    property real widthProgress: 0
    property real heightProgress: 0
    property real contentProgress: 0
    property int animationRevision: 0
    property int completedCloseRevision: -1

    readonly property real collapsedWidth:
        Config.BarTuning.rightPanelNeckWidth
        + Config.BarTuning.rightPanelFlare
    readonly property real collapsedHeight:
        Config.BarTuning.rightPanelFlare
    readonly property real openHeight: height

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
    signal closeAnimationFinished()

    focus: open

    function setProgress(widthValue, heightValue, contentValue) {
        widthProgress = widthValue
        heightProgress = heightValue
        contentProgress = contentValue
    }

    function reportCloseFinished(revision) {
        if (open
            || revision !== animationRevision
            || completedCloseRevision === revision)
            return
        completedCloseRevision = revision
        closeAnimationFinished()
    }

    function openPanel() {
        closeAnimation.stop()
        openAnimation.stop()
        animationRevision += 1

        if (reducedMotion) {
            setProgress(1, 1, 1)
            return
        }

        openAnimation.restart()
    }

    function closePanel() {
        openAnimation.stop()
        closeAnimation.stop()
        animationRevision += 1
        const revision = animationRevision

        if (reducedMotion) {
            setProgress(0, 0, 0)
            Qt.callLater(function() {
                root.reportCloseFinished(revision)
            })
            return
        }

        closeAnimation.restart()
    }

    function syncMotionPreference() {
        const wasClosing = !open
            && (closeAnimation.running
                || widthProgress > 0.001
                || heightProgress > 0.001
                || contentProgress > 0.001)
        openAnimation.stop()
        closeAnimation.stop()

        if (!reducedMotion)
            return

        animationRevision += 1
        const revision = animationRevision
        setProgress(open ? 1 : 0, open ? 1 : 0, open ? 1 : 0)
        if (wasClosing)
            Qt.callLater(function() {
                root.reportCloseFinished(revision)
            })
    }

    onOpenChanged: {
        if (open) {
            Qt.callLater(forceActiveFocus)
            openPanel()
        } else {
            closePanel()
        }
    }
    onReducedMotionChanged: syncMotionPreference()

    Component.onCompleted: {
        setProgress(open ? 1 : 0, open ? 1 : 0, open ? 1 : 0)
    }

    Keys.onEscapePressed: closeRequested()

    ParallelAnimation {
        id: openAnimation

        SequentialAnimation {
            PauseAnimation {
                duration: Config.BarTuning.panelWidthOpenDelay
            }
            NumberAnimation {
                target: root
                property: "widthProgress"
                to: 1
                duration: Config.BarTuning.panelWidthOpenDuration
                easing.type: Easing.OutCubic
            }
        }

        SequentialAnimation {
            PauseAnimation {
                duration: Config.BarTuning.panelHeightOpenDelay
            }
            NumberAnimation {
                target: root
                property: "heightProgress"
                to: 1
                duration: Config.BarTuning.panelHeightOpenDuration
                easing.type: Easing.OutQuart
            }
        }

        SequentialAnimation {
            PauseAnimation {
                duration: Config.BarTuning.panelContentInDelay
            }
            NumberAnimation {
                target: root
                property: "contentProgress"
                to: 1
                duration: Config.BarTuning.panelContentInDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    ParallelAnimation {
        id: closeAnimation

        NumberAnimation {
            target: root
            property: "contentProgress"
            to: 0
            duration: Config.BarTuning.panelContentOutDuration
            easing.type: Easing.InQuad
        }

        SequentialAnimation {
            PauseAnimation {
                duration: Config.BarTuning.panelHeightCloseDelay
            }
            NumberAnimation {
                target: root
                property: "heightProgress"
                to: 0
                duration: Config.BarTuning.panelHeightCloseDuration
                easing.type: Easing.InCubic
            }
        }

        SequentialAnimation {
            PauseAnimation {
                duration: Config.BarTuning.panelWidthCloseDelay
            }
            NumberAnimation {
                target: root
                property: "widthProgress"
                to: 0
                duration: Config.BarTuning.panelWidthCloseDuration
                easing.type: Easing.InCubic
            }
        }

        onFinished: {
            root.reportCloseFinished(root.animationRevision)
        }
    }

    Item {
        id: inputMask

        x: sizer.x
        y: Config.BarTuning.rightPanelFlare
        width: sizer.width
        height: Math.max(0, sizer.height
            - Config.BarTuning.rightPanelFlare)
    }

    Item {
        id: sizer

        anchors.top: parent.top
        anchors.right: parent.right
        width: root.collapsedWidth
            + (root.width - root.collapsedWidth)
                * root.widthProgress
        height: root.collapsedHeight
            + (root.openHeight - root.collapsedHeight)
                * root.heightProgress
        clip: true

        // 面板内部空白由此层消费，外部点击只落到宿主的关闭层。
        MouseArea {
            anchors.fill: parent
            enabled: root.open || root.widthProgress > 0.001
        }

        // 主体轮廓跟随 sizer 的当前宽高，活动左边缘始终保留完整圆角；
        // 内容仍按最终尺寸排版并由 sizer 裁剪，翻页不改变外壳几何。
        RightPanelShape {
            id: panelShape

            anchors.top: parent.top
            anchors.right: parent.right
            width: root.width
            height: sizer.height
            neckWidth: Config.BarTuning.rightPanelNeckWidth
            bodyWidth: sizer.width
            radius: Config.BarTuning.rightPanelRadius
            flare: Config.BarTuning.rightPanelFlare
            color: Config.Theme.surface
        }

        // 页面始终按最终宽度排版，展开阶段只由 sizer 裁剪。
        Item {
            id: contentStage

            anchors.top: parent.top
            anchors.right: parent.right
            width: root.width
            height: root.openHeight
            opacity: root.contentProgress
            enabled: root.contentProgress > 0.95
            visible: root.contentProgress > 0.001
            transform: Translate {
                y: 10 * (1 - root.contentProgress)
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
