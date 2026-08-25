import "../config" as Config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string icon: ""
    property string toolTip: ""
    property real value: 0
    property bool inactive: false
    property color accentColor: "#8fb3c5"
    property color surfaceColor: "#1c1c1c"
    property color textColor: "#d0d0d0"
    property color mutedColor: "#707070"
    property bool reducedMotion: false
    property bool selectorVisible: false
    property var selectorModel: []
    property int selectorCurrentIndex: -1
    property string selectorTextRole: "label"
    property string selectorPlaceholder: "NO OUTPUT"
    property bool selectorEnabled: true
    property real selectorWidth: 34
    property bool selectorExpanded: false
    property real selectorRevealHeight: selectorExpanded ? outputList.implicitHeight : 0

    readonly property int selectorCount: selectorModel && selectorModel.length
        ? selectorModel.length : 0
    readonly property string selectorSelectedLabel: selectorEntryLabel(selectorCurrentIndex)

    signal valueRequested(real value)
    signal iconClicked()
    signal selectorRequested(int index)

    Layout.fillWidth: true
    Layout.preferredHeight:
        Config.BarTuning.rightPanelControlSliderHeight
        + selectorRevealHeight
    clip: true

    Behavior on selectorRevealHeight {
        enabled: !root.reducedMotion
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    function selectorEntryLabel(index) {
        if (index < 0 || index >= selectorCount)
            return selectorPlaceholder

        const entry = selectorModel[index]
        if (entry === null || entry === undefined)
            return selectorPlaceholder
        if (typeof entry === "string")
            return entry

        return String(entry[selectorTextRole] || selectorPlaceholder)
    }

    function chooseSelectorIndex(index) {
        if (index < 0 || index >= selectorCount)
            return

        root.selectorRequested(index)
        root.selectorExpanded = false
    }

    function collapseSelector() {
        root.selectorExpanded = false
    }

    onSelectorVisibleChanged: {
        if (!selectorVisible)
            collapseSelector()
    }
    onSelectorEnabledChanged: {
        if (!selectorEnabled)
            collapseSelector()
    }
    onSelectorModelChanged: {
        if (selectorCount === 0)
            collapseSelector()
    }

    Rectangle {
        anchors.fill: parent
        radius: Config.Theme.radiusMedium
        color: root.surfaceColor
        border.color: Config.Theme.outlineVariant
    }

    RowLayout {
        id: mainRow

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 18
        height: Config.BarTuning.rightPanelControlSliderHeight
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 20
            color: iconMouse.pressed
                ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.12)
                : iconMouse.containsMouse
                    ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.07)
                    : "transparent"

            Behavior on color {
                enabled: !root.reducedMotion
                ColorAnimation { duration: Config.Theme.animFast }
            }

            Text {
                anchors.centerIn: parent
                text: root.icon
                font.family: "Material Design Icons"
                font.pixelSize: 21
                color: root.inactive ? root.mutedColor : root.accentColor
            }

            MouseArea {
                id: iconMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.iconClicked()
            }

            AppToolTip {
                anchors.bottom: parent.top
                anchors.bottomMargin: Config.Theme.spacingTiny
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.toolTip
                target: iconMouse
            }
        }

        Item {
            id: sliderTrack
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: Config.BarTuning.rightPanelSliderTrackHeight
                radius: height / 2
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.1)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.value / 100))
                    height: parent.height
                    radius: parent.radius
                    color: root.inactive ? root.mutedColor : root.accentColor

                    // 数值跳变平滑（外部更新 / 拖动都走同一动画）
                    Behavior on width {
                        enabled: !root.reducedMotion
                        NumberAnimation { duration: Config.Theme.animFast; easing.type: Easing.OutCubic }
                    }
                }
            }

            Rectangle {
                id: handle
                x: Math.max(0, Math.min(parent.width - width,
                    parent.width * root.value / 100 - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                width: Config.BarTuning.rightPanelSliderHandleSize
                height: sliderMouse.pressed
                    ? Config.BarTuning.rightPanelSliderHandleSize + 4
                    : Config.BarTuning.rightPanelSliderHandleSize
                radius: width / 2
                color: root.accentColor

                Behavior on x {
                    enabled: !root.reducedMotion
                    NumberAnimation { duration: Config.Theme.animFast; easing.type: Easing.OutCubic }
                }

                Behavior on height {
                    enabled: !root.reducedMotion
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                id: sliderMouse
                anchors.fill: parent
                preventStealing: true
                cursorShape: Qt.PointingHandCursor

                function requestAt(mouseX) {
                    const nextValue = Math.max(0, Math.min(100, mouseX / width * 100))
                    root.valueRequested(nextValue)
                }

                onPressed: mouse => requestAt(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        requestAt(mouse.x)
                }
            }
        }

        ControlCenterOutputSelector {
            id: selector

            visible: root.selectorVisible
            enabled: root.selectorEnabled && root.selectorCount > 0
            Layout.minimumWidth: visible ? root.selectorWidth : 0
            Layout.preferredWidth: visible ? root.selectorWidth : 0
            Layout.maximumWidth: visible ? root.selectorWidth : 0
            Layout.preferredHeight: 34
            expanded: root.selectorExpanded
            selectedLabel: root.selectorSelectedLabel
            accentColor: root.accentColor
            textColor: root.textColor
            mutedColor: root.mutedColor
            reducedMotion: root.reducedMotion

            onClicked: root.selectorExpanded = !root.selectorExpanded
        }

        Text {
            Layout.preferredWidth: 42
            text: Math.round(root.value) + "%"
            font.family: "JetBrains Mono"
            font.pixelSize: 12
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignRight
            color: root.textColor
        }
    }

    Item {
        id: selectorReveal

        anchors.top: mainRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.selectorRevealHeight
        visible: height > 0
        clip: true
        opacity: outputList.implicitHeight > 0
            ? Math.min(1, height / outputList.implicitHeight) : 0

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            height: 1
            color: Config.Theme.outlineVariant
        }

        ControlCenterOutputList {
            id: outputList

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            model: root.selectorModel
            currentIndex: root.selectorCurrentIndex
            textRole: root.selectorTextRole
            accentColor: root.accentColor
            textColor: root.textColor
            mutedColor: root.mutedColor

            onSelected: index => root.chooseSelectorIndex(index)
        }
    }
}
