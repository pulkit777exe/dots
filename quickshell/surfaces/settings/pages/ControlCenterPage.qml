import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"






ColumnLayout {
    id: root
    spacing: 12

    SettingsHeader {
        icon: "tune"
        title: "Control Center"
        subtitle: "Arrange, resize, add and remove the controls."
    }

    ControlCenterArranger {
        id: arranger
        Layout.fillWidth: true
        
        
        
        
        
        Layout.preferredWidth: 0
    }
}
