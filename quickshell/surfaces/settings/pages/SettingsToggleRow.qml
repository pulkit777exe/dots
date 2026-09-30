import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"





Item {
    id: root

    property string label: ""
    property bool checked: false

    signal toggled(bool value)

    
    
    
    implicitHeight: 44
    Layout.fillWidth: true

    RowLayout {
        anchors.fill: parent
        spacing: 12

        StyledText {
            Layout.fillWidth: true
            text: root.label
            font.pixelSize: 13
            
            color: Qt.rgba(1, 0.97, 0.925, 0.95)
            elide: Text.ElideRight
        }

        Toggle {
            checked: root.checked
            accentColor: Theme.colors.accent
            onToggled: (v) => root.toggled(v)
        }
    }
}
