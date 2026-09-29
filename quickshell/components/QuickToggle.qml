import QtQuick
import "../services"

// QuickToggle
// Small circular icon-only toggle — the compact quick-action style used
// in macOS Control Center's Focus row and Android's Quick Settings tiles,
// for actions that don't need (or don't fit) a text label the way
// ListRow's full-width rows do.
//
// Two visual modes:
//   - toggle (default): fills with accentColor while `active`, like a
//     Focus/Night-Shift-style on/off tile.
//   - momentary (`momentary: true`): never tints on state — just hover/
//     press feedback, for one-shot actions like Lock that don't have an
//     "on" state to represent.
Item {
    id: root

    property string icon: ""
    property bool active: false
    property bool momentary: false
    property color accentColor: Theme.colors.accent
    property color accentTextColor: Theme.colors.accentText

    signal clicked()

    width: 44
    height: 44

    readonly property bool filled: active && !momentary

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        // solid like screenshots (was translucent 0.06/0.12/0.16 on black)
        color: root.filled ? root.accentColor
            : (tapHandler.pressed ? Qt.lighter(Theme.surfaceRaised, 1.3) : (hoverHandler.hovered ? Theme.colors.surfaceAlt : Theme.colors.surface))
        Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }
    }

    Icon {
        anchors.centerIn: parent
        icon: root.icon
        size: 18
        iconColor: root.filled ? root.accentTextColor : Qt.rgba(1, 1, 1, 0.88)
        Behavior on iconColor { ColorAnimation { duration: MotionConfig.hover() } }
    }

    HoverHandler { id: hoverHandler; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tapHandler; onTapped: root.clicked() }
}
