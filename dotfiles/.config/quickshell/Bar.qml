// 模块：Bar（顶栏容器）
// 功能：组合左/中/右三个岛屿组件，形成一整条顶部栏（Bar）。
// 关联功能：
// - LeftIsland：工作区指示/切换（通常与 niri 工作区相关）
// - CenterIsland：时间显示/音量反馈（点击触发中心面板开关）
// - RightIslands：系统信息/托盘/电源按钮（点击触发系统面板开关）
// 与外部交互：
// - 通过 signal centerClicked/systemClicked 把“点击意图”上报给 shell.qml 统一处理（切换面板窗口可见性、触发数据刷新）。
// - 通过 property alias centerIsland 把 CenterIsland 实例暴露给外部（shell.qml 用它做音量反馈联动）。

import QtQuick // QML 基础类型（Rectangle/Item/锚点布局等）
import "components" // 引入本目录组件（LeftIsland/CenterIsland/RightIslands）
Rectangle {
    id: bar
    // ShellRoot 引用（由 shell.qml 注入），用于把工具函数下发到子组件（例如 CenterIsland 的 ASCII 条）
    property var root: null
    property real unit: 13.6 // 尺寸基准（由 shell 注入；用于 spacing、字体、图标等的统一缩放）
    property color zenInk: "#141414" // 主背景色（岛屿底色）
    property color zenMist: "#2a2a2a" // 边框/分割线色
    property color zenStone: "#1f1f1f" // hover 背景色
    property color zenAsh: "#3a3a3a" // 次级文本/弱对比色
    property color zenSmoke: "#5a5a5a" // 文本/图标弱化色
    property color zenCloud: "#8a8a8a" // 文本中等对比色
    property color zenSnow: "#cacaca" // 文本高对比色
    property color zenPure: "#f0f0f0" // 备用纯色（更亮的文本/图标）
    property color zenAccent: "#5a9a8a" // 强调色（进度条/高亮等）
    property color zenDanger: "#9a5555" // 通知徽标与清理操作色
    property var panelWindow: null // 顶栏所在 PanelWindow；用于托盘菜单锚点定位（RightIslands）
    property int trayDirectIconLimit: 3 // 折叠态直接显示的应用图标上限
    property int notificationHistoryCount: 0 // 磁盘历史总数，与托盘应用数独立
    property bool trayPanelExpanded: false // 托盘横向展开与历史面板的统一状态
    
    // 岛屿位置偏移参数
    property real leftIslandOffsetX: 0 // 左岛 X 偏移（由 shell 注入；用于整体微调位置）
    property real centerIslandOffsetX: 0 // 中岛 X 偏移（由 shell 注入）
    property real rightIslandOffsetX: 0 // 右岛 X 偏移（由 shell 注入）
    
    signal centerClicked() // 用户点击中岛时发出（由 shell 处理：切换中心面板）
    signal systemClicked() // 用户点击系统岛时发出（由 shell 处理：切换系统面板）
    signal trayPanelToggleRequested(real panelWidth) // 复合入口点击请求
    signal trayPanelResizeRequested(real panelWidth) // 展开中托盘数量变化后的宽度同步
    signal trayPanelCloseRequested() // 托盘项或折叠按钮请求关闭

    // 暴露中岛引用给外部
    property alias centerIsland: centerIslandItem // 对外暴露 CenterIsland 实例（用于音量反馈/动画联动）
    color: "transparent" // Bar 自身不绘制底色（由各岛屿组件绘制）

    Item {
        anchors.fill: parent // 顶栏布局填充整个 Bar 区域

        LeftIsland {
            width: implicitWidth
            height: parent.height // 高度跟随 Bar 高度（形成“岛屿”外形）
            anchors.left: parent.left
            anchors.leftMargin: bar.leftIslandOffsetX // 左岛整体 X 偏移
            anchors.verticalCenter: parent.verticalCenter
            unit: bar.unit // 传入尺寸基准
            zenInk: bar.zenInk // 传入主题色：背景
            zenMist: bar.zenMist // 传入主题色：边框/分割线
            zenStone: bar.zenStone // 传入主题色：hover
            zenCloud: bar.zenCloud // 传入主题色：中等文本
            zenSnow: bar.zenSnow // 传入主题色：高对比文本
        }

        CenterIsland {
            id: centerIslandItem
            width: implicitWidth
            height: parent.height // 高度跟随 Bar 高度
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: bar.centerIslandOffsetX // 中岛整体 X 偏移
            anchors.verticalCenter: parent.verticalCenter
            root: bar.root
            unit: bar.unit // 传入尺寸基准
            zenInk: bar.zenInk // 传入主题色：背景
            zenMist: bar.zenMist // 传入主题色：边框/分割线
            zenStone: bar.zenStone // 传入主题色：hover
            zenAsh: bar.zenAsh // 传入主题色：弱对比文本
            zenSmoke: bar.zenSmoke // 传入主题色：图标/弱文本
            zenCloud: bar.zenCloud // 传入主题色：中等文本
            zenSnow: bar.zenSnow // 传入主题色：高对比文本
            zenAccent: bar.zenAccent // 传入主题色：强调色（音量条等）
            onTogglePanel: bar.centerClicked() // 把中岛点击信号上报给外部（shell）
        }

        RightIslands {
            id: rightIslandsItem
            width: implicitWidth
            height: parent.height // 高度跟随 Bar 高度
            anchors.right: parent.right
            anchors.rightMargin: -bar.rightIslandOffsetX // 右岛 X 偏移（这里用负号保持与其他岛一致的“正值向右”语义）
            anchors.verticalCenter: parent.verticalCenter
            unit: bar.unit // 传入尺寸基准
            zenInk: bar.zenInk // 传入主题色：背景
            zenMist: bar.zenMist // 传入主题色：边框/分割线
            zenStone: bar.zenStone // 传入主题色：hover
            zenAsh: bar.zenAsh // 传入主题色：弱对比文本
            zenSmoke: bar.zenSmoke // 传入主题色：图标/弱文本
            zenCloud: bar.zenCloud // 传入主题色：中等文本
            zenSnow: bar.zenSnow // 传入主题色：高对比文本
            zenAccent: bar.zenAccent // 传入主题色：强调色（频谱/进度条等）
            zenDanger: bar.zenDanger // 传入主题色：通知徽标与清理动作
            panelWindow: bar.panelWindow // 传入窗口引用（托盘右键菜单锚点需要）
            trayDirectIconLimit: bar.trayDirectIconLimit
            notificationHistoryCount: bar.notificationHistoryCount
            trayPanelExpanded: bar.trayPanelExpanded
            onToggleSystemPanel: bar.systemClicked() // 把系统岛点击信号上报给外部（shell）
            onToggleTrayPanel: panelWidth => bar.trayPanelToggleRequested(panelWidth)
            onResizeTrayPanel: panelWidth => bar.trayPanelResizeRequested(panelWidth)
            onCloseTrayPanel: bar.trayPanelCloseRequested()
        }
    }
}
