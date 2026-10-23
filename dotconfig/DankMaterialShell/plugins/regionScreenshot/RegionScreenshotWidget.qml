import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// Click to select a region; the PNG goes to the clipboard only, like
// SUPER+CTRL+S in hyprland.lua.
PluginComponent {
    id: root

    pillClickAction: () => Quickshell.execDetached([Proc.dmsBin, "screenshot", "--no-file"])

    horizontalBarPill: Component {
        DankIcon {
            name: "screenshot_region"
            size: Theme.barIconSize(root.barThickness, -4)
            color: Theme.widgetIconColor
        }
    }

    verticalBarPill: Component {
        DankIcon {
            name: "screenshot_region"
            size: Theme.barIconSize(root.barThickness, -4)
            color: Theme.widgetIconColor
        }
    }
}
