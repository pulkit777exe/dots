import QtQuick
import QtQuick.Layouts

Item {
    id: page

    signal back()

    property int sideMargin: 0

    default property alias rows: col.data

    readonly property real contentHeight: col.implicitHeight + 26
    implicitHeight: contentHeight

    ColumnLayout {
        id: col
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.topMargin: 12
        anchors.leftMargin: page.sideMargin
        anchors.rightMargin: page.sideMargin
        spacing: 0
    }
}
