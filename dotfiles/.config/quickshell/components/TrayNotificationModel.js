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
        if (matchedIndex >= 0)
            counts[matchedIndex] += count
    }
    return counts
}

function removeNotificationByIdentity(notifications, target) {
    const list = Array.isArray(notifications) ? notifications : []
    return list.filter(notification => notification !== target)
}

function sourceCountsFromNotificationGroups(groups) {
    const buckets = []
    const indexes = Object.create(null)
    const groupList = Array.isArray(groups) ? groups : []

    for (const group of groupList) {
        const notices = group && Array.isArray(group.notifications)
            ? group.notifications : []
        for (const notice of notices) {
            const desktopEntry = String(notice && notice.desktopEntry || "").trim()
            const appName = String(notice && notice.appName || group && group.appName || "").trim()
            if (!validSourceIdentity(desktopEntry) && !validSourceIdentity(appName))
                continue

            const key = normalizedIdentity(desktopEntry) + "\u001f"
                + normalizedIdentity(appName)
            if (indexes[key] === undefined) {
                indexes[key] = buckets.length
                buckets.push({
                    "desktopEntry": desktopEntry,
                    "appName": appName,
                    "count": 1
                })
            } else {
                buckets[indexes[key]].count += 1
            }
        }
    }

    return buckets
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
