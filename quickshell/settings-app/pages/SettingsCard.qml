import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

Surface {
    id: root

    default property alias rows: col.data

    property int paddingH: 14
    property int paddingV: 6

    implicitHeight: col.implicitHeight + paddingV * 2
    Layout.fillWidth: true
    cornerRadius: 15
    backgroundColor: Theme.colors.surface
    borderWidth: 0
    shadow: false

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.leftMargin: root.paddingH
        anchors.rightMargin: root.paddingH
        anchors.topMargin: root.paddingV
        anchors.bottomMargin: root.paddingV
        spacing: 0
    }
}
