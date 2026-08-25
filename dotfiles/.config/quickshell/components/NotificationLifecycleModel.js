.pragma library

/** 从活动通知队列中按 QObject identity 移除目标通知。 */
function removeNotificationByIdentity(notifications, target) {
    const list = Array.isArray(notifications) ? notifications : []
    return list.filter(notification => notification !== target)
}

function notificationIdentifier(notification) {
    if (!notification)
        return undefined
    if (notification.id !== undefined && notification.id !== null)
        return notification.id
    if (notification.notificationId !== undefined
            && notification.notificationId !== null)
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
        const remaining = notices.filter(notification =>
            !shouldRemove(notification))
        if (remaining.length === 0)
            return next

        next.push({
            "appName": group.appName,
            "notifications": remaining,
            "critical": remaining.some(notification =>
                notificationIsCritical(notification))
        })
        return next
    }, [])
}

/** 从分组通知中按 QObject identity 移除目标通知，并清理空分组。 */
function removeNotificationFromGroupsByIdentity(groups, target) {
    return notificationGroupsWithout(
        groups, notification => notification === target)
}

/** 通知被同 ID 对象替换时，仅清除旧对象所在分组。 */
function removeReplacedNotificationFromGroups(groups, replacement) {
    const replacementId = notificationIdentifier(replacement)
    return notificationGroupsWithout(groups, notification => {
        if (notification === replacement || replacementId === undefined)
            return false
        return notificationIdentifier(notification) === replacementId
    })
}
