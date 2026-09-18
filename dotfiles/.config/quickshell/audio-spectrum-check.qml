import Quickshell
import QtQuick
import "vendor/brain"

// audio-spectrum-check.qml — CavaService 真实频谱链路端到端检查。
// 前置条件：需要有声源在播放（配合 pw-cat 循环播放 music.wav）。
// 运行：qs -p audio-spectrum-check.qml
//   ① CavaService.active = true 拉起 pw-record → worker 采集链路
//   ② 采样窗内持续记录 easedSpectrum 峰值 / bars 总和
//   ③ 结束时断言：sink 就绪、64 帧契约、bars 32×0..100、播放中能量 > 阈值
// 退出码：0 = 全部通过，1 = 存在失败项。
ShellRoot {
    id: testRoot

    property int failureCount: 0
    property int samplesSeen: 0
    property real maxEnergy: 0
    property int maxBarsSum: 0

    function expect(condition, label) {
        if (condition)
            return

        failureCount += 1
        console.error("[AudioSpectrumCheck] failed: " + label)
    }

    // ── 采样器：500ms 一次，记录能量峰值 ──────────────────────────────────────
    Timer {
        interval: 500
        repeat: true
        running: true
        onTriggered: {
            testRoot.samplesSeen += 1
            const e = CavaService.easedSpectrum
            if (e && e.length === CavaService.binCount) {
                let m = 0
                for (let i = 0; i < e.length; ++i)
                    m = Math.max(m, e[i])
                testRoot.maxEnergy = Math.max(testRoot.maxEnergy, m)
            }
            let s = 0
            const b = CavaService.bars
            if (b && b.length === CavaService.barCount) {
                for (let j = 0; j < b.length; ++j)
                    s += b[j]
                testRoot.maxBarsSum = Math.max(testRoot.maxBarsSum, s)
            }
        }
    }

    // ── 终局断言 ─────────────────────────────────────────────────────────────
    Timer {
        interval: 7000
        repeat: false
        running: true
        onTriggered: {
            testRoot.expect(CavaService.sinkName !== "", "default sink resolved (got '"
                + CavaService.sinkName + "')")
            testRoot.expect(CavaService.targetSpectrum.length === CavaService.binCount,
                "targetSpectrum is 64 bins (got " + CavaService.targetSpectrum.length + ")")
            testRoot.expect(CavaService.easedSpectrum.length === CavaService.binCount,
                "easedSpectrum is 64 bins")
            testRoot.expect(CavaService.bars.length === CavaService.barCount,
                "bars is 32 entries (got " + CavaService.bars.length + ")")

            let inRange = true
            const bars = CavaService.bars
            for (let i = 0; i < bars.length; ++i) {
                if (bars[i] < 0 || bars[i] > 100) {
                    inRange = false
                    break
                }
            }
            testRoot.expect(inRange, "bars within 0..100")

            testRoot.expect(testRoot.samplesSeen >= 10, "sampler ran (got "
                + testRoot.samplesSeen + " ticks)")
            testRoot.expect(testRoot.maxEnergy > 0.05,
                "spectrum has live energy while audio plays (max="
                + testRoot.maxEnergy.toFixed(4) + " — 确认 pw-cat 正在播放)")
            testRoot.expect(testRoot.maxBarsSum > 50,
                "bars respond to audio (sum=" + testRoot.maxBarsSum + ")")

            console.log("[AudioSpectrumCheck] done: failures=" + testRoot.failureCount
                + " sink=" + CavaService.sinkName
                + " maxEnergy=" + testRoot.maxEnergy.toFixed(4)
                + " maxBarsSum=" + testRoot.maxBarsSum)
            Qt.exit(testRoot.failureCount === 0 ? 0 : 1)
        }
    }

    Component.onCompleted: CavaService.active = true
    Component.onDestruction: CavaService.active = false
}
