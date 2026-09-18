import "../config" as Config
import QtQuick

// 临时通知浮层的增量卡片栈：按应用键复用卡片实例。分组数组整体替换时，
// 只为新分组创建卡片、就地更新已有卡片、对消失的分组播放退场，播完再销毁。
// 直接把 JS 数组绑给 Repeater 会在数组任何变化时销毁并重建全部卡片：
// 退场动画永远播不完，剩余卡片还会重放入场。
Item {
    id: root

    property var groups: []
    property real unit: 13.6
    property real cardSpacing: unit * 0.35
    property color ink: Config.Theme.surface
    property color stone: Config.Theme.surfaceContainer
    property color mist: Config.Theme.outline
    property color smoke: Config.Theme.textMuted
    property color cloud: Config.Theme.textSecondary
    property color snow: Config.Theme.textPrimary

    // 卡片列的实际高度：宿主窗口用它裁定输入区域
    readonly property real columnHeight: column.height
    // 累计创建 / 销毁的卡片数，供回归门禁验证"不重建"
    property int createdCount: 0
    property int destroyedCount: 0

    signal dismissRequested(var notification)
    signal sourceRequested(var notification)

    // 应用键 → 卡片实例（退场中的卡片仍占位，直到 exitFinished）
    property var _cards: ({})

    implicitHeight: column.height

    function keyOf(group) {
        return String(group?.appName ?? "").toLowerCase()
    }

    function cardFor(appName) {
        const card = root._cards[String(appName ?? "").toLowerCase()]
        return card === undefined ? null : card
    }

    function liveCardCount() {
        let count = 0
        for (const key in root._cards) {
            if (!root._cards[key].exiting)
                count += 1
        }
        return count
    }

    function syncCards() {
        const next = Array.isArray(root.groups) ? root.groups : []
        const seen = {}

        for (let index = 0; index < next.length; ++index) {
            const group = next[index]
            if (!group)
                continue
            const key = root.keyOf(group)
            seen[key] = true

            let card = root._cards[key]
            // 退场中的旧卡片自行播完销毁；同应用的新通知另起一张卡片
            if (card && card.exiting)
                card = null

            if (!card) {
                card = cardComponent.createObject(column, {
                    "group": group,
                    "stackKey": key
                })
                if (!card) {
                    console.warn("[NotificationPopupStack] failed to create card for " + key)
                    continue
                }
                root._cards[key] = card
                root.createdCount += 1
            } else if (card.group !== group) {
                card.group = group
            }
        }

        for (const key in root._cards) {
            const card = root._cards[key]
            if (seen[key] || card.exiting)
                continue
            const notices = card.notifications
            card.beginExit(notices.length > 0 ? notices[notices.length - 1] : null)
        }
    }

    function releaseCard(card) {
        if (root._cards[card.stackKey] === card)
            delete root._cards[card.stackKey]
        root.destroyedCount += 1
        card.destroy()
    }

    onGroupsChanged: syncCards()
    Component.onCompleted: syncCards()

    Column {
        id: column

        width: root.width
        spacing: root.cardSpacing

        // 卡片退场收拢或销毁后，下方卡片平滑上移
        move: Transition {
            NumberAnimation {
                properties: "y"
                duration: Config.Theme.animNormal
                easing.type: Easing.OutCubic
            }
        }
    }

    Component {
        id: cardComponent

        NotificationPopupGroup {
            id: card

            width: column.width
            unit: root.unit
            ink: root.ink
            stone: root.stone
            mist: root.mist
            smoke: root.smoke
            cloud: root.cloud
            snow: root.snow
            onDismissRequested: notice => root.dismissRequested(notice)
            onSourceRequested: notice => root.sourceRequested(notice)
            onExitFinished: root.releaseCard(card)
        }
    }
}
