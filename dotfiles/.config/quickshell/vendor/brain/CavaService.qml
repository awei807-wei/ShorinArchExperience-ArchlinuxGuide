pragma Singleton

// Brain_Shell CavaService shim — mock 版。原版由 cava 进程喂音频频谱；
// 这里用随机游走模拟 32 根柱子，让 PlayerCard 的频谱动起来。
// active 门控：仅面板展开且显示 Home 页且非减少动画时更新（由
// CenterDashboard 汇总注入），避免常驻 90ms 定时器空转。
// 来源：Brain_Shell (MIT) https://github.com/Brainitech/Brain_Shell
import QtQuick

QtObject {
    id: root

    readonly property int barCount: 32
    // 装饰动画活动开关：由消费方汇总驱动，不由 Item 可见性隐式推断
    property bool active: false
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
        running: root.active
        onTriggered: {
            let next = root.bars.slice()
            while (next.length < root.barCount)
                next.push(root._min)
            for (let i = 0; i < next.length; ++i)
                next[i] = root._walk(next[i])
            root.bars = next
        }
    }

    Component.onCompleted: {
        let initial = []
        for (let i = 0; i < barCount; ++i)
            initial.push(_min)
        bars = initial
    }
}
