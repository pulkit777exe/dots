import QtQuick
import "../services"

// Toggle
// Standard pill switch. accentColor defaults to this pack's mint accent
// but is fully overridable per theme.
Item {
    id: root

    property bool checked: false
    property color accentColor: Theme.colors.accent
    property color offColor: Qt.rgba(1, 1, 1, 0.16)
    property color thumbColor: "#FFFFFF"
    property bool enabled: true

    signal toggled(bool checked)

    implicitWidth: 44
    implicitHeight: 26
    opacity: enabled ? 1 : 0.4
    Behavior on opacity { OpacityAnimator { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? root.accentColor : root.offColor
        Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }
    }

    Rectangle {
        id: thumb
        width: parent.height - 4
        height: width
        radius: width / 2
        color: root.thumbColor
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 2 : 2
        Behavior on x { NumberAnimation { duration: MotionConfig.hover(); easing.type: Easing.OutCubic } }
    }

    TapHandler {
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onTapped: {
            root.checked = !root.checked
            root.toggled(root.checked)
        }
    }
}
