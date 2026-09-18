// 系统指标采样门控 / 预热时序检查。
// 运行：qs -p stats-poll-check.qml --no-color
//
// 断言：
//   ① PollTimer 激活即刻触发，热身样本在 warmupPeriod 后到达，之后回到
//      常规 period；停用后不再触发；再次激活重新热身；
//   ② 真实服务在激活后 ~600ms 内拿到首批读数（CPU/Net 差分已有两个样本，
//      Mem/Thermal/Freq 单次快照即有值），停用后样本时间戳不再更新；
//   ③ 沿正式链路 services/center/ → DashStats → services/qmldir →
//      system/*Service → PollTimer 能完整实例化（qs: 方案下同目录类型不会
//      自动发现，PollTimer 必须登记在 services/qmldir 里）。
import QtQuick
import Quickshell
// 直接导入 system/ 目录（无 qmldir），PollTimer 与各服务同处一目录
import "vendor/brain/services/system/"
import "vendor/brain/services/center/"

ShellRoot {
    id: testRoot

    property int failureCount: 0
    property var ticks: []
    property real t0: 0
    property var prevCpuT: 0

    // ③ 正式链路加载检查：类型解析失败会让整个配置加载失败
    Item {
        width: 900
        height: 500
        DashStats {
            id: stats
            anchors.fill: parent
            active: false
        }
    }

    function expect(condition, label) {
        if (condition)
            return
        failureCount += 1
        console.error("[StatsPollCheck] failed: " + label)
    }

    function near(actual, expected, tolerance, label) {
        if (Math.abs(actual - expected) <= tolerance)
            return
        failureCount += 1
        console.error("[StatsPollCheck] " + label + ": expected≈" + expected
                      + "±" + tolerance + " actual=" + actual)
    }

    function finish() {
        if (failureCount === 0) {
            console.log("[StatsPollCheck] PASS")
            Qt.exit(0)
        } else {
            console.error("[StatsPollCheck] FAIL count=" + failureCount)
            Qt.exit(1)
        }
    }

    PollTimer {
        id: clock
        period: 1000
        warmupPeriod: 300
        onTriggered: testRoot.ticks.push(Date.now() - testRoot.t0)
    }

    CpuService     { id: cpu }
    NetService     { id: net }
    MemService     { id: mem }
    ThermalService { id: thermal }
    CpuFreqService { id: cpuFreq }

    SequentialAnimation {
        running: true

        ScriptAction { script: {
            testRoot.t0 = Date.now()
            testRoot.expect(stats.active === false && stats.children.length > 0,
                "DashStats instantiated via formal import chain")
            clock.active = true
            cpu.active = true
            net.active = true
            mem.active = true
            thermal.active = true
            cpuFreq.active = true
        } }

        // 激活后 150ms：只应有"即刻"那一次触发
        PauseAnimation { duration: 150 }
        ScriptAction { script: {
            testRoot.expect(testRoot.ticks.length === 1,
                "one immediate tick at 150ms, got " + testRoot.ticks.length)
            if (testRoot.ticks.length >= 1)
                testRoot.near(testRoot.ticks[0], 0, 60, "immediate tick time")
            testRoot.expect(cpu._prev !== null, "cpu first sample landed")
            testRoot.expect(mem.totalStr !== "0", "mem snapshot landed: " + mem.totalStr)
            testRoot.expect(cpuFreq.curFreqStr !== "—",
                "cpufreq snapshot landed: " + cpuFreq.curFreqStr)
            testRoot.expect(cpuFreq.activeProfile !== "unknown",
                "governor snapshot landed: " + cpuFreq.activeProfile)
        } }

        // 激活后 600ms：热身样本（300ms）已到，常规周期（1300ms）还没到
        PauseAnimation { duration: 450 }
        ScriptAction { script: {
            testRoot.expect(testRoot.ticks.length === 2,
                "warm-up tick by 600ms, got " + testRoot.ticks.length)
            if (testRoot.ticks.length >= 2)
                testRoot.near(testRoot.ticks[1], 300, 80, "warm-up tick time")
            testRoot.expect(cpu._prev !== null && cpu._prev.t - testRoot.t0 >= 200,
                "cpu second sample landed (differential ready)")
            testRoot.expect(net._prev !== null && net._prev.t - testRoot.t0 >= 200,
                "net second sample landed (differential ready)")
            testRoot.expect(thermal.cpuTempStr !== "—",
                "thermal snapshot landed: " + thermal.cpuTempStr)
            console.log("[StatsPollCheck] cpu=" + cpu.usagePercent + "% mem="
                + mem.usagePercent + "% net↓" + net.downSpeed + " temp="
                + thermal.cpuTempStr + " freq=" + cpuFreq.curFreqStr)
        } }

        // 激活后 1500ms：第三次触发应落在 1300ms 附近（热身后回到 1s 周期）
        PauseAnimation { duration: 900 }
        ScriptAction { script: {
            testRoot.expect(testRoot.ticks.length === 3,
                "regular tick by 1500ms, got " + testRoot.ticks.length)
            if (testRoot.ticks.length >= 3)
                testRoot.near(testRoot.ticks[2], 1300, 100, "regular tick time")
            clock.active = false
            cpu.active = false
            net.active = false
            mem.active = false
            thermal.active = false
            cpuFreq.active = false
            testRoot.prevCpuT = cpu._prev ? cpu._prev.t : 0
            testRoot.ticks = []
        } }

        // 停用 1200ms：没有任何触发、样本不再更新
        PauseAnimation { duration: 1200 }
        ScriptAction { script: {
            testRoot.expect(testRoot.ticks.length === 0,
                "no ticks while inactive, got " + testRoot.ticks.length)
            testRoot.expect(cpu._prev && cpu._prev.t === testRoot.prevCpuT,
                "cpu sampling stopped while inactive")
            testRoot.t0 = Date.now()
            clock.active = true
        } }

        // 再次激活：重新走"即刻 + 热身"
        PauseAnimation { duration: 600 }
        ScriptAction { script: {
            testRoot.expect(testRoot.ticks.length === 2,
                "re-activation re-warms: expected 2 ticks, got " + testRoot.ticks.length)
            if (testRoot.ticks.length >= 2) {
                testRoot.near(testRoot.ticks[0], 0, 60, "re-activation immediate tick")
                testRoot.near(testRoot.ticks[1], 300, 80, "re-activation warm-up tick")
            }
            clock.active = false
            testRoot.finish()
        } }
    }
}
