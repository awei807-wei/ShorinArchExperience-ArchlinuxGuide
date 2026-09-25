.pragma library

function asString(value) {
    if (value === null || value === undefined)
        return ""
    return String(value).trim()
}

function isTransientChromiumSource(value) {
    var candidate = asString(value)
    if (candidate.indexOf("file://") === 0)
        candidate = candidate.substring(7)
    return candidate.indexOf("/tmp/.org.chromium.Chromium.") === 0
}

function safeSource(value) {
    var candidate = asString(value)
    return isTransientChromiumSource(candidate) ? "" : candidate
}

function safeFileUrl(value) {
    var candidate = safeSource(value)
    if (candidate === "")
        return ""
    if (/^[A-Za-z][A-Za-z0-9+.-]*:/.test(candidate))
        return candidate
    return "file://" + candidate
}
