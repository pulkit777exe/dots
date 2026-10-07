pragma ComponentBehavior: Bound

import QtQuick
import "../services"

// Four ascending bars: how much wifi there is.
//
// A wifi GLYPH plus a separate number is two readings of one fact -- the
// glyph says "connected" and the number says how good. Four bars that fill
// up are a single reading, they are the shape of the thing they measure,
// and they cost eleven logical pixels instead of an icon and a string.
//
// Heights are the reference design's, bottom-aligned and deliberately not
// evenly spaced: the steps grow so the top bar reads as headroom rather
// than as one more notch.
Item {
    id: root

    // 0..100, straight from Wifi.strength.
    property real strength: 0

    property real barWidth: 2.5
    property real spacing: 1.4

    readonly property var heights: [3.5, 5.6, 7.2, 10]

    implicitWidth: heights.length * barWidth + (heights.length - 1) * spacing
    implicitHeight: heights[heights.length - 1]

    // `> index * 25` rather than `>=`: 100 lights all four, 75 lights three,
    // and the unfilled top bar is the difference between "good" and "full".
    Repeater {
        model: root.heights.length

        delegate: Rectangle {
            required property int index

            x: index * (root.barWidth + root.spacing)
            y: root.height - height
            width: root.barWidth
            height: root.heights[index]
            radius: width / 2
            color: root.strength > index * 25
                ? Theme.colors.accent
                : Theme.withAlpha(Theme.colors.text, 0.25)

            Behavior on color {
                ColorAnimation { duration: MotionConfig.hover() }
            }
        }
    }
}
