import QtQuick





Rectangle {
    id: root

    property color scrimColor: Qt.rgba(0, 0, 0, 0.45)
    property bool dismissOnClick: true

    signal dismissed()

    color: scrimColor

    MouseArea {
        anchors.fill: parent
        enabled: root.dismissOnClick
        onClicked: root.dismissed()
    }

    
    
    MouseArea {
        anchors.fill: parent
        enabled: !root.dismissOnClick
    }
}
