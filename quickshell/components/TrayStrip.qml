import QtQuick
import "../services"

Item {
    id: root

    property int iconSize: 16

    implicitWidth: row.implicitWidth
    implicitHeight: 22
    visible: Config.trayEnabled && Tray.hasItems

    readonly property bool hovered: hoverArea.containsMouse

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: Tray.items
            delegate: TrayIcon {
                iconSize: root.iconSize
            }
        }
    }
}
