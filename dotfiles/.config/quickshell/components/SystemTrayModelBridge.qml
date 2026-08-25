import QtQuick
import Quickshell.Services.SystemTray

// 隔离 Quickshell 的 SystemTray 服务模型，并把稳定对象内部的变更转换为
// 普通 revision；数据消费者无需各自复制模型监听细节。
Item {
    id: bridge

    property var items: SystemTray.items
    property int revision: 0

    width: 0
    height: 0
    visible: false

    Connections {
        target: bridge.items && bridge.items.values !== undefined
            ? bridge.items : null
        ignoreUnknownSignals: true

        function onValuesChanged() {
            bridge.revision += 1
        }

        function onObjectInsertedPost() {
            bridge.revision += 1
        }

        function onObjectRemovedPost() {
            bridge.revision += 1
        }
    }
}
