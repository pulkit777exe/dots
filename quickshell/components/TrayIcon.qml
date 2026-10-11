import QtQuick
import Quickshell
import Quickshell.Widgets
import "../services"

Item {
    id: root

    required property var item
    property int iconSize: 16

    width: 22
    height: 22

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: Theme.withAlpha(Theme.colors.text, hover.containsMouse ? 0.12 : 0)
        Behavior on color { ColorAnimation { duration: Config.hover() } }
    }

    IconImage {
        anchors.centerIn: parent
        implicitSize: root.iconSize
        source: root.item.icon
        asynchronous: true
    }

    QsMenuAnchor {
        id: menuAnchor
        menu: root.item.hasMenu ? root.item.menu : null
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
    }

    function openMenu() {
        if (root.item.hasMenu) menuAnchor.open();
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton) {
                root.item.secondaryActivate();
            } else if (mouse.button === Qt.RightButton) {
                if (root.item.hasMenu) root.openMenu();
                else root.item.secondaryActivate();
            } else {
                if (root.item.onlyMenu) root.openMenu();
                else root.item.activate();
            }
        }
        onWheel: (wheel) => {
            root.item.scroll(wheel.angleDelta.y, false);
        }
    }
}
