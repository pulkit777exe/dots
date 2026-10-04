import QtQuick
import "../services"





Rectangle {
    id: root

    property bool interactive: false
    property color hoverColor: Theme.withAlpha(Theme.colors.text, 0.12)
    property color baseColor: Theme.withAlpha(Theme.colors.text, 0.07)

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
