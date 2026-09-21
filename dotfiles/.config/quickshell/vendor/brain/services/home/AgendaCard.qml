import QtQuick
import "../../"
import "../"
import "../../components"

// Compact task agenda for the Home dashboard.
StatCard {
    id: root
    padding: 0
    implicitWidth: 210
    clip: true

    property string selectedDate: ""
    signal clearDateFilterRequested()

    property double _nowMs: Date.now()

    readonly property var agendaTasks: {
        var source = TaskService.tasks || []
        var openTasks = source.filter(function(task) {
            if (task.column === 2)
                return false
            if (root.selectedDate === "")
                return true
            return String(task.dueDate || "").substring(0, 10) === root.selectedDate
        })
        openTasks.sort(function(a, b) {
            var aPinned = a.pinned === true
            var bPinned = b.pinned === true
            if (aPinned !== bPinned)
                return aPinned ? -1 : 1

            var aDue = root._dueMs(a.dueDate || "")
            var bDue = root._dueMs(b.dueDate || "")
            if (aDue !== bDue)
                return aDue - bDue
            return Number(a.id) - Number(b.id)
        })
        return openTasks
    }

    function _parseDue(value) {
        if (!value)
            return null
        var match = /^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}))?$/.exec(String(value))
        if (!match)
            return null

        var year = Number(match[1])
        var month = Number(match[2]) - 1
        var day = Number(match[3])
        var hasTime = match[4] !== undefined
        var hour = hasTime ? Number(match[4]) : 23
        var minute = hasTime ? Number(match[5]) : 59
        var due = new Date(year, month, day, hour, minute, hasTime ? 0 : 59, hasTime ? 0 : 999)
        if (due.getFullYear() !== year || due.getMonth() !== month || due.getDate() !== day
                || due.getHours() !== hour || due.getMinutes() !== minute)
            return null
        return due
    }

    function _dueMs(value) {
        var due = root._parseDue(value)
        return due === null ? Number.POSITIVE_INFINITY : due.getTime()
    }

    function _isOverdue(value) {
        var due = root._parseDue(value)
        return due !== null && due.getTime() < root._nowMs
    }

    function _formatDue(value) {
        var due = root._parseDue(value)
        if (due === null)
            return ""
        if (due.getTime() < root._nowMs)
            return "Overdue"

        var now = new Date(root._nowMs)
        var today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        var tomorrow = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1)
        var dayAfter = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 2)
        var dueDay = new Date(due.getFullYear(), due.getMonth(), due.getDate())
        var hasTime = String(value).length >= 16
        var time = hasTime ? String(value).substring(11, 16) : ""

        if (dueDay.getTime() === today.getTime())
            return "Today" + (time !== "" ? " " + time : "")
        if (dueDay.getTime() === tomorrow.getTime())
            return "Tomorrow" + (time !== "" ? " " + time : "")

        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        var label = months[due.getMonth()] + " " + due.getDate()
        if (dueDay.getTime() >= dayAfter.getTime() && due.getFullYear() !== now.getFullYear())
            label += " " + due.getFullYear()
        return label + (time !== "" ? " " + time : "")
    }

    function _formatSelectedDate(dateKey, uppercase) {
        var match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(dateKey))
        if (!match)
            return ""

        var monthIndex = Number(match[2]) - 1
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        if (monthIndex < 0 || monthIndex >= months.length)
            return ""

        var label = months[monthIndex] + " " + Number(match[3])
        return uppercase ? label.toUpperCase() : label
    }

    function _addTask(title) {
        var cleanTitle = String(title ?? "").trim()
        if (cleanTitle === "")
            return false
        return TaskService.addTask(0, cleanTitle, "", root.selectedDate, false) >= 0
    }

    function _quickAdd() {
        if (root._addTask(quickInput.text))
            quickInput.text = ""
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root._nowMs = Date.now()
    }

    Item {
        anchors.fill: parent

        Item {
            id: header
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 43

            Text {
                id: headerTitle
                anchors {
                    left: parent.left
                    right: filterChip.visible ? filterChip.left : countBadge.left
                    leftMargin: 12
                    rightMargin: 6
                    verticalCenter: parent.verticalCenter
                }
                text: "Agenda"
                elide: Text.ElideRight
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Rectangle {
                id: countBadge
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                width: countLabel.implicitWidth + 12
                height: 18
                radius: 9
                color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.11)

                Text {
                    id: countLabel
                    anchors.centerIn: parent
                    text: root.agendaTasks.length
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: Theme.active
                }
            }

            Rectangle {
                id: filterChip
                visible: root.selectedDate !== ""
                anchors { right: countBadge.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                width: filterLabel.implicitWidth + 14
                height: 18
                radius: 9
                color: filterHover.hovered
                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                    : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.10)
                border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.28)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 80 } }

                Text {
                    id: filterLabel
                    anchors.centerIn: parent
                    text: root._formatSelectedDate(root.selectedDate, true) + "  ×"
                    font.pixelSize: 8
                    font.weight: Font.Bold
                    color: Theme.active
                }

                HoverHandler {
                    id: filterHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onTapped: root.clearDateFilterRequested()
                }
            }

            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1
                color: Qt.rgba(1, 1, 1, 0.07)
            }
        }

        Rectangle {
            id: quickAdd
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 }
            height: 31
            radius: 8
            color: quickInput.activeFocus ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.08)
                                          : Qt.rgba(1, 1, 1, 0.04)
            border.color: quickInput.activeFocus
                ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.38)
                : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            Behavior on color { ColorAnimation { duration: 100 } }
            Behavior on border.color { ColorAnimation { duration: 100 } }

            Text {
                anchors { left: parent.left; leftMargin: 9; verticalCenter: parent.verticalCenter }
                visible: quickInput.text === ""
                text: TaskService.loaded
                    ? (root.selectedDate !== ""
                        ? "+  Add for " + root._formatSelectedDate(root.selectedDate, false)
                        : "+  Quick add")
                    : "Loading tasks…"
                font.pixelSize: 10
                color: Qt.rgba(1, 1, 1, 0.25)
            }

            TextInput {
                id: quickInput
                anchors { fill: parent; leftMargin: 9; rightMargin: 9 }
                enabled: TaskService.loaded
                clip: true
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                font.pixelSize: 11
                selectionColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
                selectByMouse: true
                Keys.onReturnPressed: function(event) {
                    root._quickAdd()
                    event.accepted = true
                }
                Keys.onEnterPressed: function(event) {
                    root._quickAdd()
                    event.accepted = true
                }
            }
        }

        Item {
            id: listArea
            anchors {
                left: parent.left
                right: parent.right
                top: header.bottom
                bottom: quickAdd.top
                bottomMargin: 6
            }
            clip: true

            Flickable {
                anchors.fill: parent
                contentWidth: width
                contentHeight: taskColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: taskColumn
                    width: parent.width

                    Repeater {
                        model: root.agendaTasks

                        delegate: Item {
                            id: taskRow
                            required property var modelData
                            width: taskColumn.width
                            height: 50
                            opacity: 1
                            property bool completing: false

                            Rectangle {
                                anchors { fill: parent; leftMargin: 5; rightMargin: 5; topMargin: 2; bottomMargin: 2 }
                                radius: 7
                                color: rowHover.hovered ? Qt.rgba(1, 1, 1, 0.045) : "transparent"
                                Behavior on color { ColorAnimation { duration: 80 } }
                            }

                            Rectangle {
                                id: doneButton
                                anchors { left: parent.left; leftMargin: 11; verticalCenter: parent.verticalCenter }
                                width: 16
                                height: 16
                                radius: 8
                                color: taskRow.completing
                                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                                    : "transparent"
                                border.color: checkHover.hovered ? Theme.active : Qt.rgba(1, 1, 1, 0.30)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 80 } }
                                Behavior on border.color { ColorAnimation { duration: 80 } }

                                Text {
                                    anchors.centerIn: parent
                                    visible: taskRow.completing
                                    text: "✓"
                                    font.pixelSize: 10
                                    color: Theme.active
                                }
                                HoverHandler { id: checkHover; cursorShape: Qt.PointingHandCursor }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !taskRow.completing
                                    onClicked: {
                                        taskRow.completing = true
                                        completeAnimation.start()
                                    }
                                }
                            }

                            Item {
                                anchors {
                                    left: doneButton.right
                                    leftMargin: 8
                                    right: pinButton.left
                                    rightMargin: 5
                                    top: parent.top
                                    bottom: parent.bottom
                                }

                                Text {
                                    id: titleLabel
                                    anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
                                    height: 16
                                    text: taskRow.modelData.title
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    font.pixelSize: 12
                                    color: Theme.text
                                }

                                Text {
                                    anchors { left: parent.left; right: parent.right; top: titleLabel.bottom; topMargin: 2 }
                                    visible: text !== ""
                                    text: root._formatDue(taskRow.modelData.dueDate || "")
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 9
                                    color: root._isOverdue(taskRow.modelData.dueDate || "")
                                        ? "#f38ba8" : Qt.rgba(1, 1, 1, 0.36)
                                }
                            }

                            Item {
                                id: pinButton
                                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                width: 22
                                height: 28

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰐃"
                                    font.pixelSize: 12
                                    color: taskRow.modelData.pinned === true
                                        ? Theme.active
                                        : pinHover.hovered ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.18)
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                }
                                HoverHandler { id: pinHover; cursorShape: Qt.PointingHandCursor }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: TaskService.patchTask(taskRow.modelData.id, "pinned", taskRow.modelData.pinned !== true)
                                }
                            }

                            Rectangle {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 12; rightMargin: 12 }
                                height: 1
                                color: Qt.rgba(1, 1, 1, 0.045)
                            }

                            HoverHandler { id: rowHover }

                            SequentialAnimation {
                                id: completeAnimation
                                NumberAnimation {
                                    target: taskRow
                                    property: "opacity"
                                    to: 0
                                    duration: 130
                                    easing.type: Easing.OutCubic
                                }
                                ScriptAction { script: TaskService.markDone(taskRow.modelData.id) }
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: !TaskService.loaded
                text: "Loading…"
                font.pixelSize: 10
                color: Qt.rgba(1, 1, 1, 0.28)
            }

            Text {
                anchors.centerIn: parent
                visible: TaskService.loaded && root.agendaTasks.length === 0
                text: root.selectedDate !== ""
                    ? "No tasks for " + root._formatSelectedDate(root.selectedDate, false)
                    : "All clear"
                font.pixelSize: 11
                color: Qt.rgba(1, 1, 1, 0.28)
            }
        }
    }
}
