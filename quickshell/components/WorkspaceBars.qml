import QtQuick
import "../services"

Item {
    id: root

    property color accent: Theme.colors.accent

    readonly property int barWidth: 6
    readonly property int barHeight: 10
    readonly property int spacing: 4
    readonly property int pitch: barWidth + spacing

    readonly property int slotCount: 5
    readonly property var slotIds: [1, 2, 3, 4, 5]

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
                SpringAnimation { spring: 6.0; damping: Config.springDamping; mass: 0.4 }
            }

            // Soft blurred glow behind the active bar (see Glow.qml).
            Glow {
                anchors.fill: parent
                anchors.margins: -6
                cornerRadius: 11
                glowColor: Theme.withAlpha(accent, 0.08)
                glowBlur: 7
                on: bar.active
            }

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
