import QtQuick
import "../services"

// SubtleScroll
// A deliberately quiet vertical scroll indicator.
//
// The Control Center's scrollable areas were left on the Flickable default,
// which draws nothing: a list taller than its box is simply sliced mid-card,
// so a truncated notification list read as a rendering fault rather than as a
// list with more below. A styled ScrollBar would need QtQuick.Controls, which
// this project does not use anywhere, so this is hand-rolled from a Rectangle
// rather than introducing a new import for one widget.
//
// The look: 3px wide, no groove, no border, fully rounded. White at 18% at
// rest, rising to 55% while the list is moving or the pointer is on it, and
// easing back down over 260ms. Accent only on hover, so it never competes
// with the content it sits over.
//
// Non-interactive by design: it observes hover with a HoverHandler and takes
// no buttons, so drags pass straight through to the Flickable underneath and
// nothing can be swallowed by an invisible 3px strip.
//
// Height comes from the parent's anchors (top + bottom); the width is fixed.
// Place it as:
//
//     SubtleScroll {
//         flickable: someFlickable
//         anchors.right: parent.right
//         anchors.top: parent.top
//         anchors.bottom: parent.bottom
//     }
Item {
    id: ind

    required property Flickable flickable

    // Gap from the flickable's own edge, so the bar never touches a card.
    property int inset: 3

    readonly property bool needed: flickable.contentHeight > flickable.height + 1
    readonly property real track: Math.max(1, height - inset * 2)
    // Proportional to the visible fraction, but never so small it is hard to
    // see or grab.
    readonly property real barSize: Math.max(20, track * (flickable.height / Math.max(1, flickable.contentHeight)))
    readonly property real travel: Math.max(0, flickable.contentHeight - flickable.height)
    readonly property real pos: travel > 0
        ? Math.max(0, Math.min(1, flickable.contentY / travel))
        : 0

    width: 3
    visible: needed
    z: 40

    Rectangle {
        id: bar
        width: 3
        height: ind.barSize
        radius: 1.5
        y: ind.inset + (ind.track - height) * ind.pos
        color: ind.containsMouse ? Theme.colors.accent : Qt.rgba(1, 1, 1, 0.5)
        opacity: 0.18

        Behavior on opacity {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            enabled: !MotionConfig.reduceMotion
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
    }

    states: State {
        name: "lit"
        when: ind.containsMouse || ind.flickable.moving
        PropertyChanges { target: bar; opacity: 0.55 }
    }

    HoverHandler { id: hover; cursorShape: Qt.ArrowCursor }

    readonly property bool containsMouse: hover.hovered
}
