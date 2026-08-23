import QtQuick
import "../../core"

/** Minimal 0..1 slider used for volume/brightness/bar-height/font-size.
 *  Deliberately not QtQuick.Controls.Slider -- one small custom control is
 *  less bloat than pulling in the Controls module + a style for one widget. */
Item {
    id: root
    property real value: 0   // 0..1, meant to be bound by the caller
    signal moved(real value)

    // Internal-only: the live position while actively dragging. Rendering
    // prefers this over `value` while pressed so the thumb tracks the mouse
    // in real time, but `value` itself is NEVER assigned from in here --
    // doing so would sever the caller's binding (e.g.
    // `value: AudioService.volume / 100`) the first time someone drags it,
    // after which the slider would stop reflecting the real source forever.
    property real _dragValue: value
    readonly property real _displayValue: mouseArea.pressed ? _dragValue : value

    implicitHeight: 24

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.colors.surfaceHover

        Rectangle {
            id: fill
            width: track.width * root._displayValue
            height: track.height
            radius: track.radius
            color: Theme.colors.accent
            Behavior on width { enabled: !mouseArea.pressed; NumberAnimation { duration: 120 } }
        }

        // Thumb knob
        Rectangle {
            id: thumb
            width: 14
            height: 14
            radius: 7
            color: Theme.colors.accent
            border.width: 2
            border.color: Theme.colors.surface
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(track.width - width, (track.width - width) * root._displayValue))
            scale: mouseArea.pressed ? 1.2 : mouseArea.containsMouse ? 1.1 : 1.0
            Behavior on scale { NumberAnimation { duration: 120 } }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        onPositionChanged: if (pressed) updateFromX(mouseX)
        onPressed: updateFromX(mouseX)
        // Always land on the final, precise value once the drag ends, even
        // if the throttle below is mid-cooldown and swallowed the last update.
        onReleased: if (moveThrottle.hasPending) { root.moved(moveThrottle.pendingValue); moveThrottle.hasPending = false }

        function updateFromX(x) {
            const clamped = Math.max(0, Math.min(1, x / root.width))
            root._dragValue = clamped
            moveThrottle.pendingValue = clamped
            moveThrottle.hasPending = true
            if (!moveThrottle.running) {
                // leading edge: emit immediately so the drag still feels instant
                root.moved(clamped)
                moveThrottle.hasPending = false
                moveThrottle.start()
            }
        }
    }

    // Rate-limits the `moved` signal to ~20/sec while dragging. Callers spawn
    // a real process per emit (wpctl/brightnessctl/playerctl), so firing on
    // every pixel of mouse movement was 30-60 process spawns/sec. The thumb
    // and fill above still track every pixel via _dragValue -- only the
    // signal driving external commands is throttled.
    Timer {
        id: moveThrottle
        interval: 50
        property real pendingValue: 0
        property bool hasPending: false
        onTriggered: {
            if (hasPending) {
                root.moved(pendingValue)
                hasPending = false
                restart()
            }
            // else: nothing arrived during this window, let the timer stop
            // naturally -- the next press starts a fresh leading-edge emit
        }
    }
}
