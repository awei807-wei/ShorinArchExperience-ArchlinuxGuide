import "../config" as Config
import QtQuick
import QtQuick.Controls as Controls

Item {
    id: root

    property var model: []
    property int currentIndex: -1
    property string textRole: "label"
    property color accentColor: "#8fb3c5"
    property color textColor: "#d0d0d0"
    property color mutedColor: "#707070"
    property int maximumVisibleItems: 4
    property int optionHeight: 38
    property int optionSpacing: 4
    property int verticalPadding: 8

    readonly property int optionCount: model && model.length ? model.length : 0
    readonly property int visibleOptionCount: Math.min(optionCount, maximumVisibleItems)

    signal selected(int index)

    implicitHeight: optionCount === 0 ? 0
        : verticalPadding * 2
            + visibleOptionCount * optionHeight
            + Math.max(0, visibleOptionCount - 1) * optionSpacing

    function textAt(index) {
        if (index < 0 || index >= optionCount)
            return ""

        const entry = model[index]
        if (entry === null || entry === undefined)
            return ""
        if (typeof entry === "string")
            return entry

        return String(entry[textRole] || "")
    }

    ListView {
        id: optionList

        anchors.fill: parent
        anchors.topMargin: root.verticalPadding
        anchors.bottomMargin: root.verticalPadding
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        model: root.model
        spacing: root.optionSpacing
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: root.currentIndex

        delegate: Controls.ItemDelegate {
            id: optionDelegate

            required property int index
            width: optionList.width
            height: root.optionHeight
            focusPolicy: Qt.StrongFocus
            highlighted: hovered || activeFocus
            Accessible.name: root.textAt(index)
            Accessible.description: index === root.currentIndex ? "当前音频输出设备" : "切换音频输出设备"

            onClicked: root.selected(index)

            contentItem: Item {
                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    text: root.textAt(optionDelegate.index)
                    font.family: "JetBrains Mono"
                    font.pixelSize: Config.Theme.fontSmall
                    font.weight: optionDelegate.index === root.currentIndex
                        ? Font.Bold : Font.Medium
                    color: optionDelegate.index === root.currentIndex
                        ? root.textColor : root.mutedColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    text: optionDelegate.index === root.currentIndex ? "󰄬" : ""
                    font.family: "Material Design Icons"
                    font.pixelSize: 15
                    color: root.accentColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            background: Rectangle {
                radius: Config.Theme.radiusSmall
                color: optionDelegate.index === root.currentIndex
                    ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.10)
                    : optionDelegate.highlighted
                        ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.055)
                        : "transparent"
                border.width: optionDelegate.activeFocus ? 1 : 0
                border.color: root.accentColor
            }
        }

        Controls.ScrollIndicator.vertical: Controls.ScrollIndicator { }
    }
}
