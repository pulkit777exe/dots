import QtQuick
import "../services"

// The battery capsule: 20x11 body with an accent fill, plus the little
// terminal nub. The track tints when charging so it reads at a glance.

Item {
    id: root

    property int percentage: 0
    property bool charging: false
    property color accent: Theme.colors.accent

    readonly property real bodyWidth: 20
    readonly property real bodyHeight: 11
    readonly property real inset: 0.75

    implicitWidth: bodyWidth + 1.5 + 2    // body + gap + terminal
    implicitHeight: bodyHeight

    Rectangle {                              // body / track
        width: root.bodyWidth
        height: root.bodyHeight
        radius: 3.5
        color: root.charging
            ? Theme.withAlpha(accent, 0.22)
            : Theme.withAlpha(Theme.colors.text, 0.16)

        Rectangle {                          // fill
            x: root.inset
            y: root.inset
            height: root.bodyHeight - 2 * root.inset
            radius: 3
            color: accent
            width: Math.max(0, (root.bodyWidth - 2 * root.inset) * Math.max(0, Math.min(1, root.percentage / 100)))
            Behavior on width {
                enabled: !Config.reduceMotion
                NumberAnimation { duration: Config.hover(); easing.type: Easing.OutCubic }
            }
        }
    }

    Rectangle {                              // terminal nub
        x: root.bodyWidth + 1.5
        y: (root.bodyHeight - 4.5) / 2
        width: 2
        height: 4.5
        radius: 1
        color: Theme.withAlpha(Theme.colors.text, 0.4)
    }
}
