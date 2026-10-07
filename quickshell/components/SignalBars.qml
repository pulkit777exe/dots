import QtQuick
import "../services"

// Wi-Fi strength as four ascending bars. `strength` is 0..100; a bar is
// lit when the strength clears its own quarter of the range.

Item {
    id: root

    property int strength: 0
    property color accent: Theme.colors.accent

    readonly property var heights: [3.5, 5.6, 7.2, 10]

    implicitWidth: 4 * 2.5 + 3 * 1.4
    implicitHeight: 10

    Repeater {
        model: 4
        delegate: Rectangle {
            required property int index
            readonly property bool lit: root.strength > index * 25

            width: 2.5
            height: root.heights[index]
            radius: 1.25
            x: index * (2.5 + 1.4)
            y: root.height - height
            color: lit ? accent : Theme.withAlpha(Theme.colors.text, 0.25)
            Behavior on color { ColorAnimation { duration: Config.hover() } }
        }
    }
}
