import QtQuick
import "../config" as Config

Item {
    id: sourceTab

    property var source: null
    property var menuWindow: null
    property bool selected: false
    property bool reducedMotion: false
    property color surfaceColor: Config.Theme.surface
    property color hoverColor: Config.Theme.surfaceContainer
    property color outlineColor: Config.Theme.outlineVariant
    property color textColor: Config.Theme.textPrimary
    property color mutedColor: Config.Theme.textMuted
    property color accentColor: Config.Theme.accent
    property color badgeColor: Config.Theme.danger
    readonly property bool hasNativeMenu: source && source.trayItem
        && source.trayItem.hasMenu
    readonly property var iconCandidates: resolveIconSources(source)
    property int iconCandidateIndex: 0
    readonly property string iconSource: iconCandidateIndex < iconCandidates.length
        ? iconCandidates[iconCandidateIndex] : ""
    readonly property string sourceLabel: String(
        source && source.label ? source.label : "Notification")
    readonly property int notificationCount: Math.max(
        0, Number(source && source.count) || 0)
    readonly property bool hovered: pointer.containsMouse
    readonly property bool displayingIcon: appIcon.visible
    readonly property bool displayingFallback: fallbackLabel.visible

    signal sourceRequested(string key)
    signal hoverChanged(var hoveredSource, var sourceItem, bool hoveredValue)

    width: Config.BarTuning.notificationSourceSlotSize
    height: Config.BarTuning.notificationSourceSlotSize
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: sourceLabel + ", " + notificationCount + " notifications"
    Accessible.description: hasNativeMenu
        ? "Left click filters notifications; right click opens the app menu"
        : "Left click filters notifications"

    function resolveIconSources(item) {
        if (!item)
            return []
        const resolved = []
        const liveTrayIcon = item.trayItem && item.trayItem.icon
            ? item.trayItem.icon : ""
        const candidates = [liveTrayIcon, item.iconSource,
                            item.desktopEntry, item.appName]
        for (const rawCandidate of candidates) {
            const candidate = String(rawCandidate || "").trim()
            if (candidate.length === 0)
                continue
            let source = candidate
            if (candidate.startsWith("/"))
                source = "file://" + candidate
            else if (!/^[A-Za-z][A-Za-z0-9+.-]*:/.test(candidate))
                source = "image://icon/" + candidate.replace(/\.desktop$/i, "")
            if (resolved.indexOf(source) < 0)
                resolved.push(source)
        }
        return resolved
    }

    function requestSource() {
        if (source)
            sourceRequested(source.key)
    }

    function openNativeMenu() {
        if (!hasNativeMenu)
            return
        if (!nativeMenuLoader.item) {
            nativeMenuLoader.setSource(
                Qt.resolvedUrl("NotificationSourceMenuAnchor.qml"), {
                    "trayItem": source && source.trayItem
                        ? source.trayItem : null,
                    "menuWindow": menuWindow,
                    "anchorItem": iconFrame
                })
        }
        if (nativeMenuLoader.item)
            nativeMenuLoader.item.openMenu()
    }

    function tryNextIcon() {
        if (iconCandidateIndex + 1 < iconCandidates.length)
            iconCandidateIndex += 1
    }

    function syncNativeMenu() {
        if (!nativeMenuLoader.item)
            return
        nativeMenuLoader.item.trayItem = source && source.trayItem
            ? source.trayItem : null
        nativeMenuLoader.item.menuWindow = menuWindow
        nativeMenuLoader.item.anchorItem = iconFrame
    }

    onSourceChanged: {
        iconCandidateIndex = 0
        if (hasNativeMenu)
            Qt.callLater(syncNativeMenu)
        else
            nativeMenuLoader.source = ""
    }
    onIconCandidatesChanged: iconCandidateIndex = 0
    onMenuWindowChanged: Qt.callLater(syncNativeMenu)
    onHasNativeMenuChanged: {
        if (!hasNativeMenu)
            nativeMenuLoader.source = ""
    }
    onHoveredChanged: hoverChanged(source, sourceTab, hovered)
    onVisibleChanged: {
        if (!visible && hovered)
            hoverChanged(source, sourceTab, false)
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Space) {
            requestSource()
            event.accepted = true
        } else if (event.key === Qt.Key_Menu && hasNativeMenu) {
            openNativeMenu()
            event.accepted = true
        }
    }

    Rectangle {
        id: iconFrame

        anchors.centerIn: parent
        width: Config.BarTuning.notificationSourceIconFrameSize
        height: width
        radius: Config.Theme.radiusSmall
        color: sourceTab.selected
            ? Qt.rgba(sourceTab.accentColor.r, sourceTab.accentColor.g,
                      sourceTab.accentColor.b, 0.16)
            : (sourceTab.hovered ? sourceTab.hoverColor : "transparent")
        border.width: 1
        border.color: sourceTab.selected
            ? sourceTab.accentColor
            : (sourceTab.hovered ? sourceTab.outlineColor : "transparent")

        Behavior on color {
            enabled: !sourceTab.reducedMotion
            ColorAnimation { duration: Config.Theme.animFast }
        }

        Behavior on border.color {
            enabled: !sourceTab.reducedMotion
            ColorAnimation { duration: Config.Theme.animFast }
        }

        Image {
            id: appIcon

            anchors.centerIn: parent
            width: Config.BarTuning.notificationSourceIconSize
            height: width
            source: sourceTab.iconSource
            sourceSize.width: width
            sourceSize.height: height
            asynchronous: true
            visible: status === Image.Ready
            onStatusChanged: {
                if (status === Image.Error)
                    sourceTab.tryNextIcon()
            }
        }

        Text {
            id: fallbackLabel

            anchors.centerIn: parent
            text: sourceTab.sourceLabel.slice(0, 1).toUpperCase() || "?"
            textFormat: Text.PlainText
            color: sourceTab.textColor
            font.family: "JetBrains Mono"
            font.pixelSize: 14
            font.weight: Font.DemiBold
            visible: !appIcon.visible
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -1
        anchors.rightMargin: -2
        height: Config.BarTuning.notificationSourceBadgeHeight
        width: Math.max(height, countText.implicitWidth + 6)
        radius: height / 2
        color: sourceTab.badgeColor
        border.width: 1
        border.color: sourceTab.surfaceColor

        Text {
            id: countText

            anchors.centerIn: parent
            text: sourceTab.notificationCount > 99
                ? "99+" : String(sourceTab.notificationCount)
            textFormat: Text.PlainText
            color: sourceTab.textColor
            font.family: "JetBrains Mono"
            font.pixelSize: Config.Theme.fontTiny
            font.weight: Font.DemiBold
        }
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 1
        anchors.bottomMargin: -1
        text: "⋮"
        color: sourceTab.mutedColor
        font.family: "JetBrains Mono"
        font.pixelSize: 10
        visible: sourceTab.hovered && sourceTab.hasNativeMenu
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: sourceTab.activeFocus ? 1 : 0
        border.color: sourceTab.textColor
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                sourceTab.openNativeMenu()
                return
            }
            sourceTab.requestSource()
        }
    }

    Loader {
        id: nativeMenuLoader

        asynchronous: false
        onLoaded: sourceTab.syncNativeMenu()
    }
}
