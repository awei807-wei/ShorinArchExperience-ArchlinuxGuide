import QtQuick

// CenterPanel（中心面板内容组件）
// - 从 shell.qml 抽离并组件化
// - 动画复刻原逻辑：height 展开 + y 微调 + opacity
Rectangle {
    id: centerPanel

    // 外部对象引用
    required property var root
    required property var centerPanelCloseTimer

    // 状态与主题属性
    property var animEasing
    property int animSpeedNormal
    property real baseUnit
    property int brightnessPercent
    property string btStatus
    property bool centerPanelClosing
    property bool centerPanelVisible
    property real fontSecondary
    property real fontSection
    property real fontTiny
    property string mediaArtist
    property bool mediaPlaying
    property real mediaPosition
    property string mediaTitle
    property var mprisPlayer
    property string netInterface
    property string netSSID
    property real panelGap
    property real panelLabelWidth
    property real panelOffsetY
    property real panelPadding
    property real panelRadius
    property real panelRowGap
    property real panelRowHeight
    property real panelSectionGap
    property real panelWidth
    property real sliderHeight
    property real sliderHitArea
    property int volumePercent
    property color zenAsh
    property color zenCloud
    property color zenInk
    property color zenMist
    property color zenSmoke
    property color zenSnow

    // 由 shell.qml 计算并注入的最终坐标
    property real panelX: 0

    // 布局与动画逻辑 (复刻 SystemPanel 风格)
    z: 1
    x: panelX
    y: panelOffsetY + (centerPanelVisible ? 0 : -8)
    width: panelWidth
    height: centerPanelVisible ? (panelContent.height + panelPadding * 2) : 0
    opacity: centerPanelVisible ? 1 : 0
    color: zenInk
    border.color: zenMist
    border.width: 1
    radius: panelRadius
    clip: true

    Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

    // 拦截背景点击，防止穿透到底层关闭
    MouseArea {
        anchors.fill: parent
        onPressed: function(mouse) { mouse.accepted = true }
        onClicked: function(mouse) { mouse.accepted = true }
    }

    Column {
        id: panelContent
        anchors.top: parent.top
        anchors.topMargin: panelPadding
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: panelSectionGap

        // ===== 盒子1: CONNECTIVITY =====
        Column {
            x: panelPadding
            width: parent.width - panelPadding * 2
            spacing: panelRowGap

            Item {
                width: parent.width; height: fontSection
                Text { text: "[ NET_IO ]"; font.pixelSize: fontSection; font.letterSpacing: 3; color: zenAsh; anchors.left: parent.left }
                Text { text: "⌜"; font.pixelSize: fontSection; color: zenMist; anchors.right: parent.right }
            }

            Item {
                width: parent.width; height: fontSecondary
                Text { anchors.left: parent.left; text: "INTERFACE"; font.pixelSize: fontSecondary; color: zenSmoke }
                Text { anchors.right: parent.right; text: netSSID; font.pixelSize: fontSecondary; color: zenCloud }
            }

            Item {
                width: parent.width; height: fontSecondary
                Text { anchors.left: parent.left; text: "ADAPTER"; font.pixelSize: fontSecondary; color: zenSmoke }
                Text { anchors.right: parent.right; text: netInterface; font.pixelSize: fontSecondary; color: zenCloud }
            }

            Item {
                width: parent.width; height: fontSecondary
                Text { anchors.left: parent.left; text: "BLUETOOTH"; font.pixelSize: fontSecondary; color: zenSmoke }
                Text { anchors.right: parent.right; text: "archshiyi - " + btStatus; font.pixelSize: fontSecondary; color: zenCloud }
            }
        }

        Text {
            x: panelPadding; width: parent.width - panelPadding * 2
            text: "─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─"
            font.pixelSize: fontTiny; color: zenMist
            horizontalAlignment: Text.AlignHCenter; clip: true
        }

        // ===== 盒子2: AUDIO / DISPLAY =====
        Column {
            x: panelPadding
            width: parent.width - panelPadding * 2
            spacing: panelRowGap

            Item {
                width: parent.width; height: fontSection
                Text { text: "[ SYS_IO ]"; font.pixelSize: fontSection; font.letterSpacing: 3; color: zenAsh; anchors.left: parent.left }
                Text { text: "⌜"; font.pixelSize: fontSection; color: zenMist; anchors.right: parent.right }
            }

            // 音量行
            Item {
                width: parent.width; height: panelRowHeight
                Text {
                    id: volLabel
                    text: "MASTER_GAIN"; font.pixelSize: fontSecondary; color: zenSmoke
                    width: panelLabelWidth * 0.5; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: volValue
                    text: volumePercent + "%"; font.pixelSize: fontSecondary; color: zenCloud
                    width: panelLabelWidth * 0.8; anchors.right: parent.right; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: volSlider
                    anchors.left: volLabel.right; anchors.right: volValue.left
                    anchors.leftMargin: panelGap * 2; anchors.rightMargin: panelGap * 2
                    text: root.getAsciiBar(volumePercent, 18)
                    font.pixelSize: fontSecondary
                    font.family: "JetBrainsMono Nerd Font"
                    color: zenCloud
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter

                    MouseArea {
                        anchors.fill: parent; anchors.margins: -sliderHitArea; cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            let pct = Math.min(Math.round(mouse.x / volSlider.width * 100), 100)
                            root.setVolume(pct)
                        }
                    }
                }
            }

            // 亮度行
            Item {
                width: parent.width; height: panelRowHeight
                Text {
                    id: briLabel
                    text: "BACKLIGHT"; font.pixelSize: fontSecondary; color: zenSmoke
                    width: panelLabelWidth * 0.5; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: briValue
                    text: brightnessPercent + "%"; font.pixelSize: fontSecondary; color: zenCloud
                    width: panelLabelWidth * 0.8; anchors.right: parent.right; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: briSlider
                    anchors.left: briLabel.right; anchors.right: briValue.left
                    anchors.leftMargin: panelGap * 2; anchors.rightMargin: panelGap * 2
                    text: root.getAsciiBar(brightnessPercent, 18)
                    font.pixelSize: fontSecondary
                    font.family: "JetBrainsMono Nerd Font"
                    color: zenCloud
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter

                    MouseArea {
                        anchors.fill: parent; anchors.margins: -sliderHitArea; cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            let pct = Math.round(mouse.x / briSlider.width * 100)
                            root.setBrightness(pct)
                        }
                    }
                }
            }
        }

        Text {
            x: panelPadding; width: parent.width - panelPadding * 2
            text: "─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─"
            font.pixelSize: fontTiny; color: zenMist
            horizontalAlignment: Text.AlignHCenter; clip: true
            visible: mediaTitle !== "No Media" && mediaTitle !== ""
        }

        // ===== 盒子3: NOW PLAYING =====
        Column {
            x: panelPadding
            width: parent.width - panelPadding * 2
            spacing: panelRowGap
            visible: mediaTitle !== "No Media" && mediaTitle !== ""

            Item {
                width: parent.width; height: fontSection
                Text { text: "// MEDIA_STREAM"; font.pixelSize: fontSection; font.letterSpacing: 3; color: zenAsh; anchors.left: parent.left }
                Text { text: "⌜"; font.pixelSize: fontSection; color: zenMist; anchors.right: parent.right }
            }

            Row {
                width: parent.width; height: baseUnit * 1.8; spacing: panelGap * 4
                Column {
                    width: parent.width - baseUnit * 4; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                    Text { text: mediaTitle; font.pixelSize: fontSecondary * 1.1; color: zenSnow; width: parent.width; elide: Text.ElideRight }
                    Text {
                        text: root.formatTime(mediaPosition) + " / " + root.formatTime(mprisPlayer?.length ?? 0)
                        font.pixelSize: fontTiny; color: zenCloud
                    }
                    Text { text: mediaArtist; font.pixelSize: fontTiny; color: zenSmoke }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter; spacing: panelGap * 2.5
                    Repeater {
                        model: ["prev", "play", "next"]
                        Rectangle {
                            width: baseUnit * 1.1; height: baseUnit * 1.1; color: "transparent"; radius: 2
                            Text {
                                anchors.centerIn: parent
                                text: modelData === "prev" ? "⏮" : (modelData === "next" ? "⏭" : (mediaPlaying ? "⏸" : "▶"))
                                font.pixelSize: fontSecondary; color: zenSmoke
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (mprisPlayer) {
                                        if (modelData === "prev") mprisPlayer.previous()
                                        else if (modelData === "next") mprisPlayer.next()
                                        else mprisPlayer.togglePlaying()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item { width: 1; height: panelGap * 2 }
    }
}
