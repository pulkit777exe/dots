import QtQuick
import QtQuick.Layouts
import "../services"

// Slider
// Pill-shaped slider: filled track, optional leading icon, optional
// trailing value label. Drag or click anywhere on the track to set value.
// Scroll wheel also adjusts value by scrollStepSize.
Item {
    id: root

    property real value: 50        // 0-100
    property real minimumValue: 0
    property real maximumValue: 100
    property string icon: ""
    property bool showValueLabel: true
    property string valueSuffix: "%"
    property bool enabled: true
    property real scrollStepSize: 5  // scroll wheel step (in value units)

    property color accentColor: Theme.colors.accent
    property color trackColor: Theme.colors.surfaceAlt
    property color iconOnFillColor: Theme.colors.accentText
    property color labelColor: Qt.rgba(1, 1, 1, 0.55)

    signal moved(real value)

    implicitHeight: 44
    transformOrigin: Item.Center
    opacity: enabled ? 1 : 0.4
    Behavior on opacity { OpacityAnimator { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

    // press feedback: a slight, springy squeeze — the same motion
    // family macOS Control Center sliders use on touch/click
    scale: dragArea.pressed ? 0.985 : 1.0
    Behavior on scale { enabled: !MotionConfig.reduceMotion; SpringAnimation { spring: 5; damping: MotionConfig.springDamping; mass: 0.5 } }

    readonly property real fraction: (value - minimumValue) / (maximumValue - minimumValue)

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.trackColor
        clip: true

        Rectangle {
            id: fill
            width: track.width * root.fraction
            height: track.height
            radius: track.radius
            color: root.accentColor

            Behavior on width {
                enabled: !dragArea.pressed && !MotionConfig.reduceMotion
                SpringAnimation { spring: 3.4; damping: MotionConfig.springDamping; mass: 0.9 }
            }
        }
    }

    // subtle hover highlight, independent of the fill
    Rectangle {
        anchors.fill: track
        radius: track.radius
        color: Qt.rgba(1, 1, 1, 0.05)
        opacity: dragArea.containsMouse && !dragArea.pressed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: MotionConfig.hover(); easing.type: Easing.OutCubic } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 8

        Icon {
            visible: root.icon.length > 0
            icon: root.icon
            size: 16
            iconColor: root.iconOnFillColor
        }

        Item { Layout.fillWidth: true }

        StyledText {
            visible: root.showValueLabel
            variant: "dayNumber"
            font.pixelSize: 13
            textColor: root.labelColor
            text: Math.round(root.value) + root.valueSuffix
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor

        function updateFromX(x) {
            const f = Math.max(0, Math.min(1, x / width))
            const v = root.minimumValue + f * (root.maximumValue - root.minimumValue)
            root.value = v
            root.moved(v)
        }

        onPressed: (mouse) => updateFromX(mouse.x)
        onPositionChanged: (mouse) => { if (pressed) updateFromX(mouse.x) }

        // Scroll wheel: adjust value up/down by scrollStepSize
        onWheel: (wheel) => {
            if (!root.enabled) return;
            const delta = (wheel.angleDelta.y > 0 ? 1 : -1) * root.scrollStepSize;
            const newVal = Math.max(root.minimumValue, Math.min(root.maximumValue, root.value + delta));
            root.value = newVal;
            root.moved(newVal);
        }
    }
}
