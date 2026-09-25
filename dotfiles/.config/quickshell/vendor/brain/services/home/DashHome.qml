import QtQuick
import "../"
import "../../components"

// Dashboard Home tab — layout only.
//
//  ┌──────────────┬───────────────────────────┬──────────────┐
//  │ ProfileCard  │  ClockCard                │              │
//  ├──────────────┤                           │  AgendaCard  │
//  │ CalendarCard │  PlayerCard               │  (open tasks)│
//  │              │                           │              │
//  └──────────────┴───────────────────────────┴──────────────┘

Item {
    id: root

    readonly property int colW:    210
    readonly property int gap:       8
    readonly property int profileH: 160
    readonly property int clockH:   220
    property string agendaDateFilter: ""
    property string _pendingAgendaDateFilter: ""
    property bool _agendaDateFilterUpdateScheduled: false

    function applyAgendaDateFilterLater(dateKey) {
        root._pendingAgendaDateFilter = String(dateKey ?? "")
        if (root._agendaDateFilterUpdateScheduled)
            return

        root._agendaDateFilterUpdateScheduled = true
        Qt.callLater(function() {
            root._agendaDateFilterUpdateScheduled = false
            const nextDate = root._pendingAgendaDateFilter
            if (root.agendaDateFilter !== nextDate)
                root.agendaDateFilter = nextDate
        })
    }

    // ── Avatar path ───────────────────────────────────────────────────────────
    property string _avatarPath: WallpaperService.avatarPath

    // The state watcher emits after a successful atomic avatar replacement.
    // Clear the source for one event-loop turn so Image releases the old texture
    // before re-reading the same stable file path.
    Connections {
        target: WallpaperService
        function onWallpaperApplied(path) {
            root._avatarPath = ""
            reloadTimer.restart()
        }
    }

    Timer {
        id: reloadTimer
        interval: 0
        repeat: false
        onTriggered: root._avatarPath = WallpaperService.avatarPath
    }

    // ── Left column ───────────────────────────────────────────────────────────
    Item {
        id: leftCol
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: root.gap }
        width: root.colW

        ProfileCard {
            id: profileCard
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: root.profileH
            avatarPath: root._avatarPath
        }

        CalendarCard {
            id: calendarCard
            anchors {
                left: parent.left; right: parent.right
                top: profileCard.bottom; topMargin: root.gap
                bottom: parent.bottom
            }
            selectedDate: root.agendaDateFilter
            onDateSelectionRequested: dateKey => root.applyAgendaDateFilterLater(dateKey)
        }
    }

    // ── Right column — Agenda fills full height ───────────────────────────────
    AgendaCard {
        id: rightCard
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: root.gap }
        width: root.colW
        selectedDate: root.agendaDateFilter
        onClearDateFilterRequested: root.applyAgendaDateFilterLater("")
    }

    // ── Center column ─────────────────────────────────────────────────────────
    Item {
        id: centerCol
        anchors {
            left:  leftCol.right;  leftMargin:  root.gap
            right: rightCard.left; rightMargin: root.gap
            top:   parent.top;     bottom:      parent.bottom
            topMargin: root.gap
        }

        ClockCard {
            id: clockCard
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: root.clockH
        }

        PlayerCard {
            anchors {
                left:   parent.left;  right:  parent.right
                top:    clockCard.bottom; topMargin: root.gap
                bottom: parent.bottom
            }
        }
    }
}
