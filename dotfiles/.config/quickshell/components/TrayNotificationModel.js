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

/** 使用顶栏同一套身份与歧义规则，返回来源对应的唯一托盘索引。 */
function trayIndexForSource(items, desktopEntry, appName) {
    const baseItems = itemArray(items)
    const hasDesktopEntry = validSourceIdentity(desktopEntry)
    let matchedIndex = uniqueDesktopMatch(baseItems, desktopEntry)

    // Desktop Entry 有多个候选时，不允许退化到更宽松的 appName 匹配。
    if (hasDesktopEntry && matchedIndex < 0) {
        const identity = normalizedIdentity(desktopEntry)
        const matches = baseItems.filter(item =>
            normalizedIdentity(itemIdentity(item)) === identity)
        if (matches.length > 1)
            return -1
    }
    if (matchedIndex < 0)
        matchedIndex = uniqueApplicationMatch(baseItems, appName)
    if (matchedIndex < 0)
        matchedIndex = uniqueQqFallbackMatch(baseItems, desktopEntry, appName)
    return matchedIndex
}

function notificationCountsForItems(items, sources) {
    const baseItems = itemArray(items)
    const counts = baseItems.map(() => 0)
    const sourceList = Array.isArray(sources) ? sources : []
    for (const source of sourceList) {
        const count = Math.max(0, Number(source && source.count) || 0)
        if (count === 0)
            continue
        const matchedIndex = trayIndexForSource(
            baseItems, source && source.desktopEntry, source && source.appName)
        if (matchedIndex >= 0)
            counts[matchedIndex] += count
    }
    return counts
}

function historyAliases(entry) {
    const aliases = []
    if (validSourceIdentity(entry && entry.desktopEntry))
        aliases.push("desktop:" + normalizedIdentity(entry.desktopEntry))
    if (validSourceIdentity(entry && entry.appName))
        aliases.push("app:" + normalizedIdentity(entry.appName))
    return aliases.length > 0 ? aliases : ["fallback:notification"]
}

function aliasesOverlap(left, right) {
    return left.some(alias => right.indexOf(alias) >= 0)
}

function entryTimestamp(entry) {
    const timestamp = Number(entry && entry.timestamp)
    return isFinite(timestamp) ? timestamp : 0
}

function mergeHistoryGroup(target, source) {
    for (const alias of source.aliases) {
        if (target.aliases.indexOf(alias) < 0)
            target.aliases.push(alias)
    }
    target.records = target.records.concat(source.records)
}

function aggregateHistoryGroups(entries) {
    const groups = []
    for (let index = 0; index < entries.length; index++) {
        const candidate = {
            "aliases": historyAliases(entries[index]),
            "records": [{"entry": entries[index], "index": index}]
        }
        const matches = []
        for (let groupIndex = 0; groupIndex < groups.length; groupIndex++) {
            if (aliasesOverlap(groups[groupIndex].aliases, candidate.aliases))
                matches.push(groupIndex)
        }
        if (matches.length === 0) {
            groups.push(candidate)
            continue
        }
        const target = groups[matches[0]]
        mergeHistoryGroup(target, candidate)
        for (let matchIndex = matches.length - 1; matchIndex > 0; matchIndex--) {
            const sourceIndex = matches[matchIndex]
            mergeHistoryGroup(target, groups[sourceIndex])
            groups.splice(sourceIndex, 1)
        }
    }
    return groups
}

function historyGroupDetails(group) {
    const chronological = group.records.slice().sort((left, right) => {
        const difference = entryTimestamp(right.entry) - entryTimestamp(left.entry)
        return difference !== 0 ? difference : left.index - right.index
    })
    const entries = group.records.slice().sort((left, right) =>
        left.index - right.index).map(record => record.entry)
    let desktopEntry = ""
    let appName = ""
    let appIcon = ""
    let label = ""
    for (const record of chronological) {
        const entry = record.entry || {}
        desktopEntry = desktopEntry || String(entry.desktopEntry || "").trim()
        appName = appName || String(entry.appName || "").trim()
        appIcon = appIcon || String(entry.appIcon || "").trim()
        if (!label && validSourceIdentity(entry.appName))
            label = String(entry.appName).trim()
    }
    if (!label && validSourceIdentity(desktopEntry))
        label = String(desktopEntry).replace(/\.desktop$/i, "").trim()
    const aliases = group.aliases.slice().sort()
    const desktopAliases = aliases.filter(alias => alias.startsWith("desktop:"))
    return {
        "key": desktopAliases.length > 0 ? desktopAliases[0] : aliases[0],
        "aliases": aliases,
        "label": label || appName || "Notification",
        "desktopEntry": desktopEntry,
        "appName": appName,
        "appIcon": appIcon,
        "entries": entries,
        "count": entries.length,
        "latestTimestamp": chronological.length > 0
            ? entryTimestamp(chronological[0].entry) : 0
    }
}

function trayIndexForHistoryGroup(items, group) {
    const matches = []
    for (const record of group.records) {
        const entry = record.entry || {}
        const index = trayIndexForSource(items, entry.desktopEntry, entry.appName)
        if (index >= 0 && matches.indexOf(index) < 0)
            matches.push(index)
    }
    return matches.length === 1 ? matches[0] : -1
}

/** 将历史记录计算为可供 QML 消费的有序来源数组，并在首位插入 ALL。 */
function buildHistorySources(entries, trayItems, sourceCounts) {
    const allEntries = Array.isArray(entries) ? entries.slice() : []
    const baseItems = itemArray(trayItems)
    const groups = aggregateHistoryGroups(allEntries)
    for (const group of groups)
        group.trayIndex = trayIndexForHistoryGroup(baseItems, group)

    // 身份字符串不同但落到同一活跃托盘对象时，再合并为一个视觉来源。
    const consolidated = []
    for (const group of groups) {
        const target = group.trayIndex < 0 ? null : consolidated.find(item =>
            item.trayIndex === group.trayIndex)
        if (target) {
            mergeHistoryGroup(target, group)
        } else {
            consolidated.push(group)
        }
    }

    const orderedTrayItems = sortedItems(baseItems, sourceCounts)
    const sources = consolidated.map(group => {
        const details = historyGroupDetails(group)
        const trayItem = group.trayIndex >= 0 ? baseItems[group.trayIndex] : null
        details.trayItem = trayItem
        details.trayBacked = trayItem !== null
        details.trayIndex = group.trayIndex
        details.trayOrder = trayItem ? orderedTrayItems.indexOf(trayItem) : -1
        details.iconSource = String(
            (trayItem && trayItem.icon) || details.appIcon || "")
        return details
    })
    sources.sort((left, right) => {
        if (left.trayBacked !== right.trayBacked)
            return left.trayBacked ? -1 : 1
        if (left.trayBacked)
            return left.trayOrder - right.trayOrder
        const timeDifference = right.latestTimestamp - left.latestTimestamp
        return timeDifference !== 0
            ? timeDifference : left.label.localeCompare(right.label)
    })
    sources.unshift({
        "key": "__all__",
        "aliases": ["__all__"],
        "label": "ALL",
        "desktopEntry": "",
        "appName": "",
        "appIcon": "",
        "entries": allEntries,
        "count": allEntries.length,
        "latestTimestamp": allEntries.reduce((latest, entry) =>
            Math.max(latest, entryTimestamp(entry)), 0),
        "trayItem": null,
        "trayBacked": false,
        "trayIndex": -1,
        "trayOrder": -1,
        "iconSource": ""
    })
    return sources
}

/** 按稳定来源键查找来源；不存在时返回 null。 */
function sourceForKey(sources, key) {
    const sourceList = Array.isArray(sources) ? sources : []
    for (const source of sourceList) {
        if (source && source.key === key)
            return source
    }
    return null
}

/** 重建来源后按精确键、别名交集、ALL 的顺序恢复选择。 */
function sourceKeyForSelection(sources, previousKey, previousAliases) {
    const exact = sourceForKey(sources, previousKey)
    if (exact)
        return exact.key
    const aliases = Array.isArray(previousAliases) ? previousAliases : []
    for (const source of (Array.isArray(sources) ? sources : [])) {
        if (source && aliasesOverlap(source.aliases || [], aliases))
            return source.key
    }
    const allSource = sourceForKey(sources, "__all__")
    return allSource ? allSource.key : "__all__"
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
