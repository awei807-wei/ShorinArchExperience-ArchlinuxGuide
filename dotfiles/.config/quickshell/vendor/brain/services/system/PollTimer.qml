// Brain_Shell PollTimer — 系统指标各 *Service 共用的轮询时钟。
// 相比裸 Timer 多两件事：
//   ① 激活即刻采样（triggeredOnStart），不用先空等一个周期；
//   ② 可选"热身"：激活后的第二次采样提前到 warmupPeriod，差分类指标
//      （CPU 占用、网速）要两个样本才有首个读数，热身把这个等待从一个
//      周期压到几百毫秒；之后回落到常规 period。
// 在 onTriggered 里改 interval 会让 Timer 以新周期重新计时（QQmlTimer
// 的 update 语义），热身结束后不会多出一次即时触发。
import QtQuick

Timer {
    id: clock

    property bool active: false
    // 常规采样周期（ms）
    property int period: 1000
    // 热身周期（ms）：0 = 不热身
    property int warmupPeriod: 0

    property int _ticks: 0

    running: active
    repeat: true
    triggeredOnStart: true
    interval: warmupPeriod > 0 && _ticks < 2 ? warmupPeriod : period

    // 每次激活都重新热身（收起再展开也要尽快拿到新鲜读数）
    onRunningChanged: if (running) _ticks = 0
    onTriggered: if (_ticks < 2) _ticks += 1
}
