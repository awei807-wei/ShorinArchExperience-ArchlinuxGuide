import QtQuick
import "../../"
import "../../../../config" as Config

// 日期槽位常驻；切月和节假日返回时只更新属性，不重建图元与输入处理器。
Item {
    id: cell

    required property var day
    required property bool isToday
    required property bool isSelected
    required property bool hasOpenTask
    signal dateSelectionRequested(string dateKey)

    readonly property bool currentMonth: day ? day.cur : false
    readonly property string dateKey: currentMonth ? day.dateKey : ""
    readonly property var dayStatus: currentMonth ? day.dayStatus : null
    readonly property bool showHolidayBadge: dayStatus !== null
        && (dayStatus.kind === "holiday" || dayStatus.kind === "makeup")
    readonly property color badgeTone: dayStatus !== null && dayStatus.kind === "holiday"
        ? Config.Theme.danger : Config.Theme.accentTertiary

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) - 4
        height: width
        radius: width / 2
        color: cell.isSelected ? Theme.active
            : cell.isToday ? Qt.rgba(166 / 255, 208 / 255, 247 / 255, 0.15)
            : hover.hovered && cell.currentMonth ? Qt.rgba(1, 1, 1, 0.07)
            : "transparent"
        border.color: cell.isToday
            ? (cell.isSelected ? Theme.background
                : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35))
            : "transparent"
        border.width: cell.isToday ? 1 : 0
        Behavior on color { ColorAnimation { duration: 80 } }

        Text {
            anchors.centerIn: parent
            text: cell.day ? cell.day.n : ""
            font.pixelSize: 9
            font.family: "JetBrains Mono"
            font.weight: cell.isSelected || cell.isToday ? Font.Bold : Font.Normal
            color: cell.isSelected ? Theme.background
                : cell.isToday ? Theme.active
                : cell.currentMonth ? Qt.rgba(205 / 255, 214 / 255, 244 / 255, 0.55)
                : Qt.rgba(1, 1, 1, 0.13)
        }

        Rectangle {
            visible: cell.showHolidayBadge
            anchors {
                right: parent.right
                top: parent.top
                rightMargin: -2
                topMargin: -2
            }
            width: 12
            height: 10
            radius: 3
            color: cell.isSelected ? Config.Theme.surfaceContainer
                : Qt.rgba(cell.badgeTone.r, cell.badgeTone.g, cell.badgeTone.b, 0.24)
            border.color: cell.isSelected ? cell.badgeTone : "transparent"
            border.width: cell.isSelected ? 1 : 0

            Text {
                anchors.centerIn: parent
                text: cell.dayStatus ? cell.dayStatus.label : ""
                font.pixelSize: 7
                font.weight: Font.Bold
                color: cell.isSelected ? Config.Theme.textPrimary
                    : cell.dayStatus && cell.dayStatus.kind === "holiday"
                        ? Config.Theme.danger : Config.Theme.textMuted
            }
        }

        Rectangle {
            visible: cell.hasOpenTask
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 1
            }
            width: 3
            height: 3
            radius: 1.5
            color: cell.isSelected ? Theme.background : Theme.active
        }
    }

    HoverHandler {
        id: hover
        enabled: cell.currentMonth
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        enabled: cell.currentMonth
        acceptedButtons: Qt.LeftButton
        onTapped: cell.dateSelectionRequested(cell.dateKey)
    }
}
