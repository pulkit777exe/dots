import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"










StyledText {
    id: root

    property string label: ""
    property bool upperCase: false

    Layout.fillWidth: true
    Layout.leftMargin: 4
    
    
    
    
    
    
    Layout.topMargin: -2
    Layout.bottomMargin: -2
    font.pixelSize: 11
    font.weight: Font.DemiBold
    font.letterSpacing: upperCase ? 1.0 : 0.0
    font.capitalization: upperCase ? Font.AllUppercase : Font.MixedCase
    text: root.label
    textColor: Qt.rgba(1, 1, 1, 0.4)
}
