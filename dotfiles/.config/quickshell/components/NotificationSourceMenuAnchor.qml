import QtQuick
import Quickshell

// QsMenuAnchor 依赖运行中的 Wayland 窗口和原生托盘菜单；独立加载可让
// 纯布局/模型检查在没有 SystemTray 服务时仍然实例化筛选栏。
Item {
    id: menuBridge

    property var trayItem: null
    property var menuWindow: null
    property var anchorItem: null

    width: 0
    height: 0
    visible: false

    function openMenu() {
        if (trayItem && trayItem.hasMenu)
            trayMenu.open()
    }

    QsMenuAnchor {
        id: trayMenu
        menu: menuBridge.trayItem ? menuBridge.trayItem.menu : null
        anchor.window: menuBridge.menuWindow
        anchor.item: menuBridge.anchorItem
    }
}
