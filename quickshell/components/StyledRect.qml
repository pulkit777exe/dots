import QtQuick
import "../services"

// StyledRect
// Bare themed rounded rectangle — the generic building block for small
// content blocks (album art, cell backgrounds) that don't need Surface's
// shadow/border machinery.
Rectangle {
    id: root

    property bool interactive: false
    property color hoverColor: Qt.rgba(1, 1, 1, 0.12)
    property color baseColor: Qt.rgba(1, 1, 1, 0.07)

    radius: 8
    color: interactive && hoverHandler.hovered ? hoverColor : baseColor
    antialiasing: true

    Behavior on color { ColorAnimation { duration: MotionConfig.hover() } }

    HoverHandler {
        id: hoverHandler
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
    }
}
