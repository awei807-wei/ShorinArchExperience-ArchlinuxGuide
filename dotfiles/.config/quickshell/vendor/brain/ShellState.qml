pragma Singleton

// Brain_Shell ShellState shim — mock 版。原版承载 Wi-Fi/蓝牙/勿扰/录屏等
// 全局开关；这里全部给静态假值，待接入本配置真实服务时替换。
// 来源：Brain_Shell (MIT) https://github.com/Brainitech/Brain_Shell
import QtQuick

QtObject {
    property bool wifiOn: true
    property bool btPowered: true
    property bool btConnected: false
    property bool hotspot: false
    property bool dnd: false
    property bool focusMode: false
    property bool screenRecord: false
    readonly property string configProvider: "mock"
}
