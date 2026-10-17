import QtQuick
import "../services"

// Accent check badge marking the applied item in the pickers.
Rectangle {
    id: root

    property bool selected: false

    visible: selected
    width: 16
    height: 16
    radius: width / 2
    color: Theme.colors.accent
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: 8

    Icon {
        anchors.centerIn: parent
        icon: "check"
        size: 11
        iconColor: Theme.colors.accentText
    }
}
