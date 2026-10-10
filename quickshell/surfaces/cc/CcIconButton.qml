import QtQuick
import "../../components"
import "../../services"

Rectangle {
    id: disc

    property bool active: false
    property string icon: ""
    property color accent: Theme.accentFor("control-center")

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
        SpringAnimation { spring: 6; damping: Config.springDamping; mass: 0.4 }
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
