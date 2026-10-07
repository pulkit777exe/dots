import QtQuick
import "../services"

// A battery you read as a length: a rounded cell, the charge filled in from
// the left, and a terminal on the right.
//
// It replaces the battery ring that used to sit in the right-hand dot —
// since deleted with it. The ring was a circle you had to compare against
// its own track to read, and the number lived in a settings page rather
// than next to it; a bar's length IS its value, so this one is legible at
// the four logical pixels of margin the pill gives it, and the terminal on
// the right is what makes it read as a cell rather than as a progress bar.
Item {
    id: root

    property real percentage: 0

    // Charging tints the empty part of the cell too, so a low battery that
    // is plugged in looks different from a low battery that is not -- the
    // one fact a charge bar cannot carry on its own.
    property bool charging: false

    readonly property real bodyWidth: 20
    readonly property real bodyHeight: 11
    readonly property real inset: 0.75
    readonly property real terminalWidth: 2
    readonly property real terminalHeight: 4.5
    readonly property real terminalGap: 1.5

    readonly property real fillFraction: Math.max(0, Math.min(1, percentage / 100))

    implicitWidth: bodyWidth + terminalGap + terminalWidth
    implicitHeight: bodyHeight

    Rectangle {
        id: body

        y: (root.height - height) / 2
        width: root.bodyWidth
        height: root.bodyHeight
        radius: 3.5
        color: root.charging
            ? Theme.withAlpha(Theme.colors.accent, 0.22)
            : Theme.withAlpha(Theme.colors.text, 0.16)

        Rectangle {
            id: fill

            x: root.inset
            y: root.inset
            width: Math.max(0, (root.bodyWidth - 2 * root.inset) * root.fillFraction)
            height: root.bodyHeight - 2 * root.inset
            radius: 3
            color: Theme.colors.accent

            Behavior on width {
                enabled: !MotionConfig.reduceMotion
                NumberAnimation {
                    duration: MotionConfig.hover()
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    Rectangle {
        id: terminal

        x: root.bodyWidth + root.terminalGap
        y: (root.height - height) / 2
        width: root.terminalWidth
        height: root.terminalHeight
        radius: 1
        color: Theme.withAlpha(Theme.colors.text, 0.4)
    }
}
