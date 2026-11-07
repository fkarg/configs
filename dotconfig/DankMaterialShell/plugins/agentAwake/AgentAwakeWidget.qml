import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// Shows how many coding agents hold the lid/sleep lock (scripts/agent-awake),
// or a warning icon while a temperature/battery cutoff cools down. Click
// toggles a manual stay-awake that, unlike DMS's idle inhibitor, also keeps
// running with the lid closed. Safety cutoffs live in the script, not here.
PluginComponent {
    id: root

    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/agent-awake"
    property int agents: 0
    property bool manual: false
    property string cutoff: ""
    readonly property string icon: cutoff ? "warning" : (agents > 0 || manual) ? "coffee" : "bedtime"
    readonly property color iconColor: cutoff ? Theme.error : (agents > 0 || manual) ? Theme.primary : Theme.widgetIconColor

    function refresh() {
        Proc.runCommand("agentAwake.status", [bin, "status"], (output, exitCode) => {
            if (exitCode !== 0)
                return;
            try {
                const s = JSON.parse(output);
                agents = s.agents;
                manual = s.manual;
                cutoff = s.cutoff;
            } catch (e) {}
        }, 0);
    }

    pillClickAction: () => Proc.runCommand("agentAwake.toggle", [bin, "manual", "toggle"], () => refresh(), 0)

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: root.icon
                size: Theme.barIconSize(root.barThickness, -4)
                color: root.iconColor
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.agents > 0
                text: root.agents
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                color: Theme.widgetTextColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                name: root.icon
                size: Theme.barIconSize(root.barThickness, -4)
                color: root.iconColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                visible: root.agents > 0
                text: root.agents
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                color: Theme.widgetTextColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
