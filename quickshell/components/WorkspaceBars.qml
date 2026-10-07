pragma ComponentBehavior: Bound

import QtQuick
import "../services"

// One vertical bar per workspace: the bar you are on, teal, taller and
// glowing; the rest short and dim.
//
// The active bar is declared the SAME width as every other one and grows
// with `scale` instead. That is the only reason the pill's width is stable:
// a wider active bar would push every bar after it to the right, so the
// island would resize on every Super+N, and the clock next to it would
// slide half a pixel each time. `scale` is a transform, so it costs no
// layout -- the group is n bars wide whichever one is active.
//
// The glow is a second rectangle behind the bar, drawn at 1.4x1.25 of the
// bar and then carried through the same scale, which lands it at roughly
// 11x16 against a 6x10 bar -- the halo the reference design measures.
Item {
    id: root

    // Which screen's workspaces to show. One island is built per monitor and
    // an indicator showing every workspace on every screen reads as a bug,
    // so the filter is per screen rather than global.
    //
    // It is deliberately permissive: a workspace whose monitor we cannot name
    // is shown rather than dropped. A missing bar is a much worse failure
    // than a redundant one, and the two cases are indistinguishable from
    // inside this file.
    property string screenName: ""

    property real barWidth: 6
    property real barHeight: 10
    property real spacing: 4

    // How far the active bar grows. 1.3 is what the reference design's active
    // bar measures against its neighbours: 7.8 wide against 6.
    property real activeScale: 1.3

    readonly property var list: Workspaces.items.filter(function (w) {
        if (!root.screenName)
            return true
        var m = w.monitor
        if (!m || !m.name)
            return true
        return m.name === root.screenName
    })

    readonly property int activeIndex: {
        for (var i = 0; i < list.length; i++)
            if (list[i].id === Workspaces.focusedId)
                return i
        return -1
    }

    // Fixed for a given workspace count, whichever bar is active.
    implicitWidth: list.length > 0
        ? list.length * barWidth + (list.length - 1) * spacing
        : 0

    // Tall enough to contain the active bar's scaled height, so the group is
    // centred on its tallest member rather than clipping it.
    implicitHeight: barHeight * activeScale

    Repeater {
        model: root.list

        delegate: Item {
            id: bar

            required property var modelData
            required property int index

            readonly property bool active: index === root.activeIndex

            width: root.barWidth
            height: root.barHeight
            x: index * (root.barWidth + root.spacing)
            y: (root.height - height) / 2
            scale: active ? root.activeScale : 1.0

            Behavior on scale {
                enabled: !MotionConfig.reduceMotion
                SpringAnimation {
                    spring: 6.0
                    damping: 0.65
                    mass: 0.4
                }
            }

            Rectangle {
                id: glow
                anchors.centerIn: parent
                width: bar.width * 1.4
                height: bar.height * 1.25
                radius: width / 2
                color: Theme.withAlpha(Theme.colors.accent, 0.16)
                opacity: bar.active ? 1 : 0

                Behavior on opacity {
                    enabled: !MotionConfig.reduceMotion
                    NumberAnimation {
                        duration: MotionConfig.hover()
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Rectangle {
                id: barBody
                anchors.fill: parent
                radius: width / 2
                color: bar.active
                    ? Theme.colors.accent
                    : Theme.withAlpha(Theme.colors.text, 0.22)

                Behavior on color {
                    ColorAnimation { duration: MotionConfig.hover() }
                }
            }
        }
    }

    // Which bar sits under a local x.
    //
    // The face owns the island's one MouseArea (see the note there), so a
    // per-bar MouseArea would live underneath it and never see a press.
    // Hit-testing therefore starts here instead: each bar owns one pitch of
    // the row, spacing included, so a click in the gap next to a bar counts
    // as that bar rather than as dead space.
    function indexAt(x) {
        if (list.length === 0)
            return -1
        var i = Math.floor(x / (barWidth + spacing))
        return (i >= 0 && i < list.length) ? i : -1
    }
}
