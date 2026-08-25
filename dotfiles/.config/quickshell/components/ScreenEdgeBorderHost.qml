import "../config" as Config
import QtQuick
import Quickshell

Scope {
    id: host

    required property var shellRoot
    readonly property real barBottom: shellRoot.barMarginTop + shellRoot.barHeight

    Variants {
        model: Quickshell.screens

        delegate: Component {
            ScreenEdgeBorder {
                required property var modelData

                screen: modelData
                edge: "left"
                barBottom: host.barBottom
                thickness: Config.BarTuning.screenEdgeBorderWidth
                cornerRadius: Config.BarTuning.screenEdgeCornerRadius
                surfaceColor: Config.Theme.surface
            }
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            ScreenEdgeBorder {
                required property var modelData

                screen: modelData
                edge: "right"
                barBottom: host.barBottom
                thickness: Config.BarTuning.screenEdgeBorderWidth
                cornerRadius: Config.BarTuning.screenEdgeCornerRadius
                surfaceColor: Config.Theme.surface
            }
        }
    }
}
