// 历史通知卡片。名称保留 Stack 以兼容旧面板接口，但每个实例只代表一条通知。
import "../config" as Config
import QtQuick
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: notificationCard

    property var entry: null
    property int entryCount: 0
    property bool ready: true
    property bool selected: false
    property bool reducedMotion: false
    property real unit: 13.6
    property color zenInk: Config.Theme.surface
    property color zenStone: Config.Theme.surfaceContainer
    property color zenMist: Config.Theme.outline
    property color zenAsh: Config.Theme.outlineVariant
    property color zenSmoke: Config.Theme.textMuted
    property color zenCloud: Config.Theme.textSecondary
    property color zenSnow: Config.Theme.textPrimary
    property color zenAccent: Config.Theme.accent
    property color zenDanger: Config.Theme.danger

    readonly property int minimumHeight: Config.BarTuning.notificationCardMinHeight
        ?? 88
    readonly property string appNameText: String(entry?.appName || "Notification")
        .replace(/\s+/g, " ").trim()
    readonly property string summaryText: String(entry?.summary || "Notification")
        .replace(/\s+/g, " ").trim()
    readonly property string bodyText: String(entry?.body || "")
        .replace(/\s+/g, " ").trim()
    readonly property string urgencyText: formatUrgency(entry?.urgency)
    readonly property string iconSource: resolveIconSource(entry)

    signal copyRequested(var requestedEntry)
    signal moveRequested(int delta)

    implicitWidth: 320
    implicitHeight: Math.max(minimumHeight, textColumn.implicitHeight + 28)
    height: implicitHeight
    visible: ready && entry !== null
    radius: Config.BarTuning.notificationCardRadius ?? 14
    color: cardMouse.containsMouse
        ? Qt.lighter(zenStone, 1.08)
        : (selected ? Qt.rgba(zenStone.r, zenStone.g, zenStone.b, 0.82)
                   : Qt.rgba(zenInk.r, zenInk.g, zenInk.b, 0.96))
    border.width: 1
    border.color: entry?.urgency === "Critical"
        || String(entry?.urgency || "").toLowerCase() === "critical"
        ? zenDanger
        : (selected ? zenAccent : zenMist)
    clip: true

    function timestampInMilliseconds(timestamp) {
        const numeric = Number(timestamp || 0)
        if (!isFinite(numeric) || numeric <= 0)
            return 0
        // 测试夹具和旧日志可能使用 Unix 秒，持久化的新记录使用毫秒。
        return numeric < 100000000000 ? numeric * 1000 : numeric
    }

    function displayTime(timestamp) {
        const milliseconds = timestampInMilliseconds(timestamp)
        const date = new Date(milliseconds)
        if (milliseconds <= 0 || isNaN(date.getTime()))
            return "Unknown time"

        const age = Math.max(0, Date.now() - milliseconds)
        if (age < 60000)
            return "Just now"
        if (age < 3600000)
            return Math.floor(age / 60000) + "m ago"
        if (age < 86400000)
            return Math.floor(age / 3600000) + "h ago"
        return Qt.formatDateTime(date, "MM-dd HH:mm")
    }

    function displayClockTime(timestamp) {
        const milliseconds = timestampInMilliseconds(timestamp)
        const date = new Date(milliseconds)
        if (milliseconds <= 0 || isNaN(date.getTime()))
            return ""
        return Qt.formatTime(date, "HH:mm")
    }

    function formatUrgency(value) {
        const text = String(value || "Normal").trim().toLowerCase()
        if (text.length === 0)
            return "Normal"
        return text.charAt(0).toUpperCase() + text.slice(1)
    }

    function resolveIconSource(item) {
        if (!item)
            return ""
        const candidates = [item.appIcon, item.desktopEntry, item.appName]
        for (const rawCandidate of candidates) {
            const candidate = String(rawCandidate || "").trim()
            if (candidate.length === 0)
                continue
            if (candidate.startsWith("/"))
                return "file://" + candidate
            if (candidate.includes("://"))
                return candidate
            const desktopName = candidate.replace(/\.desktop$/, "")
            if (Quickshell.hasThemeIcon(desktopName))
                return Quickshell.iconPath(desktopName)
            if (Quickshell.hasThemeIcon(candidate))
                return Quickshell.iconPath(candidate)
        }
        return ""
    }

    function animateSwitch() {
        if (reducedMotion)
            return
        switchPulse.restart()
    }

    Behavior on color {
        enabled: !notificationCard.reducedMotion
        ColorAnimation { duration: Config.Theme.animFast }
    }

    Behavior on border.color {
        enabled: !notificationCard.reducedMotion
        ColorAnimation { duration: Config.Theme.animFast }
    }

    SequentialAnimation {
        id: switchPulse

        NumberAnimation {
            target: notificationCard
            property: "opacity"
            to: 0.42
            duration: Config.Theme.animFast / 2
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: notificationCard
            property: "opacity"
            to: 1
            duration: Config.Theme.animFast
            easing.type: Easing.OutCubic
        }
    }

    Row {
        id: cardRow

        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        Rectangle {
            id: iconFrame

            width: 36
            height: 36
            radius: 10
            color: Qt.rgba(zenAccent.r, zenAccent.g, zenAccent.b, 0.18)
            border.width: 1
            border.color: Qt.rgba(zenAccent.r, zenAccent.g, zenAccent.b, 0.32)

            IconImage {
                id: appIcon

                anchors.centerIn: parent
                width: 24
                height: 24
                source: notificationCard.iconSource
                asynchronous: true
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                text: notificationCard.appNameText.slice(0, 1).toUpperCase() || "?"
                color: notificationCard.zenSnow
                font.family: "JetBrains Mono"
                font.pixelSize: 15
                font.weight: Font.DemiBold
                visible: !appIcon.visible
            }
        }

        Column {
            id: textColumn

            width: Math.max(0, cardRow.width - iconFrame.width - cardRow.spacing)
            spacing: 4

            Row {
                width: parent.width
                spacing: 8

                Text {
                    width: Math.max(0, parent.width - timeText.width - parent.spacing)
                    text: notificationCard.appNameText
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: notificationCard.zenCloud
                    font.family: "JetBrains Mono"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                Text {
                    id: timeText

                    text: notificationCard.displayClockTime(
                        notificationCard.entry?.timestamp)
                    color: notificationCard.zenSmoke
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignRight
                }
            }

            Text {
                width: parent.width
                text: notificationCard.summaryText
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: notificationCard.zenSnow
                font.family: "JetBrains Mono"
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Text {
                visible: notificationCard.bodyText.length > 0
                width: parent.width
                text: notificationCard.bodyText
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                color: notificationCard.zenCloud
                font.family: "JetBrains Mono"
                font.pixelSize: 13
                lineHeight: 1.16
            }

            Text {
                width: parent.width
                text: notificationCard.urgencyText + " · "
                    + notificationCard.displayTime(notificationCard.entry?.timestamp)
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: notificationCard.zenSmoke
                font.family: "JetBrains Mono"
                font.pixelSize: 11
            }
        }
    }

    MouseArea {
        id: cardMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: notificationCard.copyRequested(notificationCard.entry)
        onWheel: wheel => {
            notificationCard.moveRequested(wheel.angleDelta.y < 0 ? 1 : -1)
            wheel.accepted = true
        }
    }
}
