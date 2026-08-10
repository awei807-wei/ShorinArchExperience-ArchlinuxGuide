.pragma library

function normalizedText(value) {
    return String(value || "").trim()
}

function nodeKey(node) {
    if (!node)
        return ""

    const numericId = Number(node.id)
    if (isFinite(numericId))
        return String(numericId)

    return normalizedText(node.name)
}

function isOutputNode(node) {
    return node !== null
        && node !== undefined
        && node.audio !== null
        && node.audio !== undefined
        && node.isSink === true
        && node.isStream !== true
}

function baseLabel(node) {
    if (!node)
        return "NO OUTPUT"

    const nickname = normalizedText(node.nickname)
    if (nickname)
        return nickname

    const description = normalizedText(node.description)
    if (description)
        return description

    const name = normalizedText(node.name)
    if (name)
        return name

    const key = nodeKey(node)
    return key ? "OUTPUT " + key : "AUDIO OUTPUT"
}

function compareNodes(left, right) {
    const labelOrder = baseLabel(left).localeCompare(baseLabel(right))
    if (labelOrder !== 0)
        return labelOrder

    const leftId = Number(left?.id)
    const rightId = Number(right?.id)
    if (isFinite(leftId) && isFinite(rightId) && leftId !== rightId)
        return leftId - rightId

    return nodeKey(left).localeCompare(nodeKey(right))
}

function disambiguator(node, base) {
    const name = normalizedText(node?.name)
    if (name && name !== base)
        return name

    const key = nodeKey(node)
    return key ? "#" + key : "DEVICE"
}

function options(nodes) {
    const values = nodes || []
    const outputs = []

    for (let index = 0; index < values.length; ++index) {
        const node = values[index]
        if (isOutputNode(node))
            outputs.push(node)
    }

    outputs.sort(compareNodes)

    const labelCounts = {}
    for (let index = 0; index < outputs.length; ++index) {
        const label = baseLabel(outputs[index])
        labelCounts[label] = (labelCounts[label] || 0) + 1
    }

    return outputs.map(node => {
        const base = baseLabel(node)
        const label = labelCounts[base] > 1
            ? base + " · " + disambiguator(node, base)
            : base
        return {
            "id": nodeKey(node),
            "label": label,
            "node": node
        }
    })
}

function currentIndex(outputOptions, currentNode) {
    if (!currentNode)
        return -1

    const currentKey = nodeKey(currentNode)
    const values = outputOptions || []

    for (let index = 0; index < values.length; ++index) {
        const option = values[index]
        if (option?.node === currentNode || (currentKey && option?.id === currentKey))
            return index
    }

    return -1
}
