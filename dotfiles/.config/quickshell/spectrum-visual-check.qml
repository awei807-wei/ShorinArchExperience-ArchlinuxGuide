import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "vendor/brain"
import "vendor/brain/components"
import "config" as Config

// spectrum-visual-check.qml — SpectrumVisualizer 可视化目测窗口。
//   pw-cat 播放声源后运行：quickshell -p spectrum-visual-check.qml
//   配合 grim 截图确认三层渲染与 matugen 动态配色。
// 本窗口独立于 shell.qml 运行，因此内置与 shell.qml applyDynamicColors
// 相同的 colors.json → Config.Theme 映射，使截图反映真实 matugen 主题色。
ShellRoot {
    PanelWindow {
        visible: true
        implicitWidth: 480
        implicitHeight: 160
        color: "#101418"
        exclusionMode: ExclusionMode.Ignore

        SpectrumVisualizer {
            anchors {
                fill: parent
                margins: 16
            }
            spectrum: CavaService.easedSpectrum
            running: true
        }
    }

    // 与 shell.qml 相同的 matugen 字段 → Config.Theme token 映射
    FileView {
        path: "file:///home/shiyi/.cache/matugen/colors.json"
        watchChanges: true
        onLoaded: _apply()
        onFileChanged: _apply()

        function _apply() {
            try {
                const c = JSON.parse(text()).colors
                if (!c || !c.primary) return
                Config.Theme.accent = c.primary
                Config.Theme.surface = c.surface
                Config.Theme.textPrimary = c.on_surface
                Config.Theme.textSecondary = c.outline
                Config.Theme.surfaceContainer = c.surface_container
                Config.Theme.outline = c.outline_variant
                Config.Theme.accentSecondary = c.secondary
                Config.Theme.accentTertiary = c.tertiary
                console.log("[SpectrumVisualCheck] matugen applied: primary=" + c.primary
                    + " Theme.active=" + Config.Theme.accent)
            } catch (error) {
                console.warn("[SpectrumVisualCheck] colors.json parse failed: " + error)
            }
        }
        Component.onCompleted: _apply()
    }

    Component.onCompleted: CavaService.active = true
    Component.onDestruction: CavaService.active = false
}
