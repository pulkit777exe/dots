import QtQuick
import "../services"




Item {
    id: root

    property bool checked: false
    property color accentColor: Theme.colors.accent
    
    
    
    
    
    
    
    
    // The knob. Was the hardcoded cream `#F6E2CB` on every theme; `text` is the
    // closest palette key (on gruvbox, #ebdbb2 -- an 11/15/31 shift) and is a
    // palette key rather than a colour the palette never chose. `accentText`
    // would be the token for a glyph drawn ON an accent fill; this is a knob
    // that sits on the off-track, and it wants the light end of the ramp. A
    // caller that wants the on-accent knob overrides it -- surfaces/cc/ does,
    // with `cc.onAccent`.
    property color offColor: Theme.withAlpha(Theme.colors.text, 0.11)
    property color thumbColor: Theme.colors.text
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
