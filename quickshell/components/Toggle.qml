import QtQuick
import "../services"

Rectangle {
    id: root

    property bool checked: false
    property color accent: Theme.colors.accent

    signal toggled(bool value)

    width: 44
    height: 26
    radius: height / 2
    color: checked ? accent : Theme.withAlpha(Theme.colors.text, 0.11)
    opacity: enabled ? 1 : 0.4

    Behavior on color { ColorAnimation { duration: Config.hover() } }

    Rectangle {
        width: 18
        height: 18
        radius: width / 2
        color: Theme.colors.text
        x: root.checked ? root.width - width - 4 : 4
        anchors.verticalCenter: parent.verticalCenter

        Behavior on x {
            enabled: !Config.reduceMotion
            SpringAnimation { spring: 5.5; damping: 0.68; mass: 0.4 }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
