pragma Singleton

// Brain_Shell CavaService shim — mock 版。原版由 cava 进程喂音频频谱；
// 这里用随机游走模拟 32 根柱子，让 PlayerCard 的频谱动起来。
// 来源：Brain_Shell (MIT) https://github.com/Brainitech/Brain_Shell
import QtQuick

QtObject {
    readonly property int barCount: 32
    property var bars: []

    readonly property int _min: 6
    readonly property int _max: 100

    function _walk(value) {
        const next = value + (Math.random() * 44 - 22)
        return Math.max(_min, Math.min(_max, Math.round(next)))
    }

    property Timer walkTimer: Timer {
        interval: 90
        repeat: true
        running: true
        onTriggered: {
            let next = CavaService.bars.slice()
            while (next.length < CavaService.barCount)
                next.push(CavaService._min)
            for (let i = 0; i < next.length; ++i)
                next[i] = CavaService._walk(next[i])
            CavaService.bars = next
        }
    }

    Component.onCompleted: {
        let initial = []
        for (let i = 0; i < barCount; ++i)
            initial.push(_min)
        bars = initial
    }
}
