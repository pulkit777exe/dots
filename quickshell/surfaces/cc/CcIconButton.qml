import QtQuick
import "../../components"
import "../../services"

// The round control: lock, night light. 60x60 disc, tints with its
// accent when active.

Rectangle {
    id: disc

    property bool active: false
    property string icon: ""
    property color accent: Theme.colors.accent

    signal clicked()

    width: 60
    height: 60
    radius: width / 2
    color: active
        ? Theme.withAlpha(accent, 0.22)
        : (area.containsMouse ? Theme.cc.cardHover : Theme.cc.card)
    border.color: Theme.cc.border
    border.width: 1

    Behavior on color { ColorAnimation { duration: Config.hover() } }

    scale: area.pressed ? 0.95 : 1.0
    Behavior on scale {
        enabled: !Config.reduceMotion
        SpringAnimation { spring: 6; damping: 0.7; mass: 0.4 }
    }

    Icon {
        anchors.centerIn: parent
        icon: disc.icon
        size: 19
        iconColor: disc.active ? disc.accent : Theme.withAlpha(Theme.colors.text, 0.85)
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: disc.clicked()
    }
}
