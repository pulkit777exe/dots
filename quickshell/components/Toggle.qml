import QtQuick
import "../services"

// Toggle
// Standard pill switch. accentColor defaults to this pack's mint accent
// but is fully overridable per theme.
Item {
    id: root

    property bool checked: false
    property color accentColor: Theme.colors.accent
    // Both measured off the references, not chosen:
    //   offColor   -- (44,40,37) sitting on a (16,14,12) card, i.e. a *warm*
    //                 white at ~11%. The neutral rgba(1,1,1,0.16) this used
    //                 landed at (54,53,51): lighter, and grey not warm.
    //   thumbColor -- (246,224,200) cream. The settings slider knobs and the
    //                 Control Center knobs both sample the same value
    //                 ((244,227,213) / (249,227,198)); plain #FFFFFF was far
    //                 too cold and bright against every one of them.
    property color offColor: Qt.rgba(1, 0.93, 0.88, 0.11)
    property color thumbColor: "#F6E2CB"
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
        // 18px inside a 26px track. The reference's settings toggle measures
        // an 18px knob (2026-09-20_22-30-18); this was height - 4 = 22.
        width: parent.height - 8
        height: width
        radius: width / 2
        color: root.thumbColor
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 4 : 4
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
