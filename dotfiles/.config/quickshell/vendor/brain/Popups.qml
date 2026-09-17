pragma Singleton

// Brain_Shell Popups shim — 只保留被移植页面引用的最小接口。
// 来源：Brain_Shell (MIT) https://github.com/Brainitech/Brain_Shell
import QtQuick

QtObject {
    // 仪表盘开合由外部 CenterPanelController 写入
    property bool dashboardOpen: false
    property string dashboardPage: "home"
    property int dashboardPageWidth: 900

    function closeAll() {
        dashboardOpen = false
    }
}
