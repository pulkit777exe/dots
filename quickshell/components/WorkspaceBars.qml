import QtQuick
import "../services"

// The workspace dots: five fixed slots, slot i standing for workspace i+1,
// the focused one scaled up on a spring with a soft glow behind it.
//
// The face owns the island's single MouseArea (it has to, so hover covers
// the whole pill), so per-bar MouseAreas would never see a press -- hit
// tests go through indexAt(x) instead, and a click in the gap next to a
// bar counts as that bar.

Item {
    id: root

    // Set per screen by the island; the slots are the same five everywhere,
    // so occupancy is read globally instead of filtered to this monitor.
    property color accent: Theme.colors.accent

    readonly property int barWidth: 6
    readonly property int barHeight: 10
    readonly property int spacing: 4
    readonly property int pitch: barWidth + spacing

    // Five slots by contract, never "however many workspaces exist".
    readonly property int slotCount: 5
    readonly property var slotIds: [1, 2, 3, 4, 5]

    // Fixed at five so the pill's rest layout never jumps as workspaces
    // appear; tall enough for the active bar's 1.3x, so the row centres
    // on its tallest member instead of clipping it.
    implicitWidth: slotCount * barWidth + (slotCount - 1) * spacing
    implicitHeight: Math.round(barHeight * 1.3)

    Repeater {
        model: root.slotIds

        delegate: Item {
            id: bar
            required property int index
            required property var modelData

            readonly property int wsId: modelData
            readonly property var ws: Workspaces.items.find(function (w) { return w.id === bar.wsId; })
            readonly property bool active: Workspaces.focusedId === wsId
            readonly property bool occupied: !!ws && ws.toplevels.values.length > 0

            width: root.barWidth
            height: root.barHeight
            x: index * root.pitch
            y: (root.height - height) / 2
            scale: active ? 1.3 : 1.0
            transformOrigin: Item.Center

            Behavior on scale {
                enabled: !Config.reduceMotion
                SpringAnimation { spring: 6.0; damping: 0.65; mass: 0.4 }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 8.4
                height: 12.5
                radius: width / 2
                color: Theme.withAlpha(accent, 0.16)
                opacity: bar.active ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Config.hover(); easing.type: Easing.OutCubic } }
            }

            // Colour ladder, all palette keys: focused takes the accent,
            // occupied a softened foreground (full foreground read as too
            // bright), an empty slot the muted grey.
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: bar.active ? accent
                    : bar.occupied ? Theme.withAlpha(Theme.colors.foreground, 0.8)
                    : Theme.colors.muted
                Behavior on color { ColorAnimation { duration: Config.hover() } }
            }
        }
    }

    function indexAt(x: real): int {
        const i = Math.floor(x / pitch);
        return (i >= 0 && i < slotCount) ? i : -1;
    }

    function focusSlot(i: int) {
        if (i >= 0 && i < slotCount) Workspaces.focusIndex(i);
    }
}
