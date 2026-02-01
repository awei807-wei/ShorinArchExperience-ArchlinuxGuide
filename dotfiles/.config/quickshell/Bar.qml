import QtQuick
import QtQuick.Layouts
import "components"
Rectangle {
    id: bar
    property real unit: 13.6
    property color zenInk: "#141414"
    property color zenMist: "#2a2a2a"
    property color zenStone: "#1f1f1f"
    property color zenAsh: "#3a3a3a"
    property color zenSmoke: "#5a5a5a"
    property color zenCloud: "#8a8a8a"
    property color zenSnow: "#cacaca"
    property color zenPure: "#f0f0f0"
    property var panelWindow: null
    
    // 岛屿位置偏移参数
    property real leftIslandOffsetX: 0
    property real centerIslandOffsetX: 0
    property real rightIslandOffsetX: 0
    
    signal centerClicked()
    signal systemClicked()

    // 暴露中岛引用给外部
    property alias centerIsland: centerIslandItem
    color: "transparent"
    
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 0
        anchors.rightMargin: 0
        spacing: unit * 0.8
        
        LeftIsland {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.fillHeight: true
            Layout.leftMargin: bar.leftIslandOffsetX
            unit: bar.unit
            zenInk: bar.zenInk
            zenMist: bar.zenMist
            zenStone: bar.zenStone
            zenCloud: bar.zenCloud
            zenSnow: bar.zenSnow}
        
        Item { Layout.fillWidth: true }
        
        CenterIsland {
            id: centerIslandItem
            Layout.alignment: Qt.AlignCenter | Qt.AlignVCenter
            Layout.fillHeight: true
            Layout.leftMargin: bar.centerIslandOffsetX
            unit: bar.unit
            zenInk: bar.zenInk
            zenMist: bar.zenMist
            zenStone: bar.zenStone
            zenAsh: bar.zenAsh
            zenSmoke: bar.zenSmoke
            zenCloud: bar.zenCloud
            zenSnow: bar.zenSnow
            onTogglePanel: bar.centerClicked()}
        
        Item { Layout.fillWidth: true }
        
        RightIslands {
            id: rightIslandsItem
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.fillHeight: true
            Layout.rightMargin: -bar.rightIslandOffsetX
            unit: bar.unit
            zenInk: bar.zenInk
            zenMist: bar.zenMist
            zenStone: bar.zenStone
            zenAsh: bar.zenAsh
            zenSmoke: bar.zenSmoke
            zenCloud: bar.zenCloud
            zenSnow: bar.zenSnow
            panelWindow: bar.panelWindow
            onToggleSystemPanel: bar.systemClicked()
        }
    }
}