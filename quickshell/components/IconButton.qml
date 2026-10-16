import QtQuick
import QtQuick.Layouts
import "../services"

// 28px ghost icon button: centered icon, pointer cursor, no background.
Item {
    id: root

    property string icon: ""
    property int iconSize: 16
    property color iconColor: Theme.withAlpha(Theme.colors.text, 0.5)

    signal clicked()

    Layout.preferredWidth: 28
    Layout.preferredHeight: 28
    implicitWidth: 28
    implicitHeight: 28

    Icon {
        anchors.centerIn: parent
        icon: root.icon
        size: root.iconSize
        iconColor: root.iconColor
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
