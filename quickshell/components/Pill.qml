import QtQuick
import "../services"





Rectangle {
    id: root

    default property alias content: inner.data
    property real horizontalPadding: 8
    property real verticalPadding: 4
    property color pillColor: Theme.colors.accent

    implicitWidth: inner.implicitWidth + horizontalPadding * 2
    implicitHeight: inner.implicitHeight + verticalPadding * 2

    color: pillColor
    radius: height / 2
    antialiasing: true

    Item {
        id: inner
        anchors.centerIn: parent
        
        
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
