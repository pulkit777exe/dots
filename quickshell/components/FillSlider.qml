import QtQuick
import "../services"

// Slider: a pill track with an accent fill and the leading icon sitting on the
// fill, as used across the control center and settings.
Item {
    id: root

    property real value: 0
    property string icon: ""
    property color trackColor: Theme.cc.track
    property color accent: Theme.colors.accent
    property bool wheelSteps: true

    signal moved(real fraction)
    signal scrolled(int direction)

    function clamp(v) { return Math.max(0, Math.min(1, v)); }

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
