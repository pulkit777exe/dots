import QtQuick
import "../services"

// The control centre's slider: near-black track, accent fill with the
// glyph sitting inside it, drag anywhere on the row to set, wheel to step.
// The percentage label belongs to the caller -- it sits outside the track.

Item {
    id: root

    property real value: 0            // 0..1
    property string icon: ""
    property color trackColor: Theme.cc.track
    property color accent: Theme.colors.accent
    property bool wheelSteps: true
    property real wheelDelta: 0.05

    signal moved(real fraction)
    signal scrolled(int direction)

    function clamp(v) { return Math.max(0, Math.min(1, v)); }

    // One track-height of fill even at 0, so the glyph always has a chip.
    readonly property real fillWidth: Math.max(height, width * clamp(value))

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.trackColor
        clip: true

        Rectangle {
            width: root.fillWidth
            height: parent.height
            radius: parent.radius
            color: root.accent
            Behavior on width {
                enabled: !dragArea.pressed && !Config.reduceMotion
                SpringAnimation { spring: 3.6; damping: Config.springDamping; mass: 0.9 }
            }
        }

        Icon {
            visible: root.icon.length > 0
            icon: root.icon
            size: 14
            x: 9
            anchors.verticalCenter: parent.verticalCenter
            iconColor: Theme.colors.accentText
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: (mouse) => root.moved(root.clamp(mouse.x / root.width))
        onPositionChanged: (mouse) => { if (pressed) root.moved(root.clamp(mouse.x / root.width)); }
        onWheel: (wheel) => {
            if (root.wheelSteps)
                root.scrolled(wheel.angleDelta.y > 0 ? 1 : -1);
        }
    }
}
