// Brain_Shell FanControl — 保留为状态记忆（本机无风扇控制面板依赖的
// nbfc-linux；mode 持久化在内存，仅驱动 FanPanel 的档位按钮 UI）。
import QtQuick

QtObject {
    property string mode: "auto"

    function setMode(next) {
        mode = next
    }
}
