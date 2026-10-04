import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"






Surface {
    id: root

    
    default property alias content: col.data

    
    
    
    
    
    
    
    
    
    property int paddingH: 14
    
    
    
    property int paddingV: 2

    implicitHeight: col.implicitHeight + paddingV * 2
    Layout.fillWidth: true
    cornerRadius: 16
    
    
    
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
