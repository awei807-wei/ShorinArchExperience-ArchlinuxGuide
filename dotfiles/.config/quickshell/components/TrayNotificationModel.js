.pragma library

function itemArray(items) {
    if (Array.isArray(items))
        return items.slice()
    if (items && items.values) {
        const result = []
        for (let index = 0; index < items.values.length; index++)
            result.push(items.values[index])
        return result
    }
    return []
}

function normalizedIdentity(value) {
    let normalized = String(value || "").trim().toLowerCase()
    if (normalized.length === 0)
        return ""
    normalized = normalized.replace(/\\/g, "/")
    normalized = normalized.slice(normalized.lastIndexOf("/") + 1)
    if (normalized.endsWith(".desktop"))
        normalized = normalized.slice(0, -8)
    return normalized
}

function validSourceIdentity(value) {
    const normalized = normalizedIdentity(value)
    return normalized !== ""
        && normalized !== "unknown"
        && normalized !== "notification"
}

function itemIdentity(item) {
    if (!item)
        return ""
    if (item.id !== undefined)
        return item.id
    if (item.trayId !== undefined)
        return item.trayId
    return ""
}

function uniqueDesktopMatch(items, desktopEntry) {
    if (!validSourceIdentity(desktopEntry))
        return -1
    const sourceIdentity = normalizedIdentity(desktopEntry)
    const matches = []
    for (let index = 0; index < items.length; index++) {
        if (normalizedIdentity(itemIdentity(items[index])) === sourceIdentity)
            matches.push(index)
    }
    return matches.length === 1 ? matches[0] : -1
}

function uniqueApplicationMatch(items, appName) {
    if (!validSourceIdentity(appName))
        return -1
    const sourceIdentity = normalizedIdentity(appName)
    const matches = []
    for (let index = 0; index < items.length; index++) {
        const item = items[index]
        const identities = [itemIdentity(item), item && item.title, item && item.tooltipTitle]
        if (identities.some(value => normalizedIdentity(value) === sourceIdentity))
            matches.push(index)
    }
    return matches.length === 1 ? matches[0] : -1
}

function emptyIdentityField(value) {
    return String(value || "").trim() === ""
}

function uniqueQqFallbackMatch(items, desktopEntry, appName) {
    const desktopIdentity = normalizedIdentity(desktopEntry)
    const appIdentity = normalizedIdentity(appName)
    if (desktopIdentity !== "qq" && appIdentity !== "qq")
        return -1

    const matches = []
    for (let index = 0; index < items.length; index++) {
        const item = items[index]
        if (normalizedIdentity(itemIdentity(item)) !== "chrome_status_icon_1")
            continue
        if (!emptyIdentityField(item && item.title)
                || !emptyIdentityField(item && item.tooltipTitle)
                || !emptyIdentityField(item && item.tooltipDescription))
            continue
        matches.push(index)
    }
    return matches.length === 1 ? matches[0] : -1
}

function notificationCountsForItems(items, sources) {
    const counts = items.map(() => 0)
    const sourceList = Array.isArray(sources) ? sources : []
    for (const source of sourceList) {
        const count = Math.max(0, Number(source && source.count) || 0)
        if (count === 0)
            continue
        const desktopEntry = source && source.desktopEntry
        const appName = source && source.appName
        const hasDesktopEntry = validSourceIdentity(desktopEntry)
        const desktopMatch = uniqueDesktopMatch(items, desktopEntry)

        // Prefer Desktop Entry, but never fall through from an ambiguous
        // Desktop Entry to a looser app-name match. That would attribute a
        // notification to an arbitrary tray item when several IDs normalize
        // to the same value.
        let matchedIndex = desktopMatch
        if (hasDesktopEntry && desktopMatch < 0) {
            const desktopIdentity = normalizedIdentity(desktopEntry)
            const desktopMatches = items.filter(item =>
                normalizedIdentity(itemIdentity(item)) === desktopIdentity)
            if (desktopMatches.length > 1)
                continue
        }
        if (matchedIndex < 0)
            matchedIndex = uniqueApplicationMatch(items, appName)
        if (matchedIndex < 0)
            matchedIndex = uniqueQqFallbackMatch(items, desktopEntry, appName)
        if (matchedIndex >= 0)
            counts[matchedIndex] += count
    }
    return counts
}

function removeNotificationByIdentity(notifications, target) {
    const list = Array.isArray(notifications) ? notifications : []
    return list.filter(notification => notification !== target)
}

function notificationIdentifier(notification) {
    if (!notification)
        return undefined
    if (notification.id !== undefined && notification.id !== null)
        return notification.id
    if (notification.notificationId !== undefined && notification.notificationId !== null)
        return notification.notificationId
    return undefined
}

function notificationIsCritical(notification) {
    if (!notification)
        return false
    const urgency = notification.urgency
    return Number(urgency) === 2
        || String(urgency || "").trim().toLowerCase() === "critical"
}

function notificationGroupsWithout(groups, shouldRemove) {
    const groupList = Array.isArray(groups) ? groups : []
    return groupList.reduce((next, group) => {
        const notices = group && Array.isArray(group.notifications)
            ? group.notifications : []
        const remaining = notices.filter(notification => !shouldRemove(notification))
        if (remaining.length === 0)
            return next

        let critical = false
        for (const notification of remaining) {
            if (notificationIsCritical(notification)) {
                critical = true
                break
            }
        }
        next.push({
            "appName": group.appName,
            "notifications": remaining,
            "critical": critical
        })
        return next
    }, [])
}

function removeNotificationFromGroupsByIdentity(groups, target) {
    return notificationGroupsWithout(groups, notification => notification === target)
}

function removeReplacedNotificationFromGroups(groups, replacement) {
    const replacementId = notificationIdentifier(replacement)
    return notificationGroupsWithout(groups, notification => {
        if (notification === replacement || replacementId === undefined)
            return false
        return notificationIdentifier(notification) === replacementId
    })
}

function sortedItems(items, sources) {
    const baseItems = itemArray(items)
    const counts = notificationCountsForItems(baseItems, sources)
    return baseItems.map((item, index) => ({
        "item": item,
        "baseIndex": index,
        "notificationCount": counts[index]
    })).sort((left, right) => {
        const countDifference = right.notificationCount - left.notificationCount
        return countDifference !== 0 ? countDifference : left.baseIndex - right.baseIndex
    }).map(entry => entry.item)
}
