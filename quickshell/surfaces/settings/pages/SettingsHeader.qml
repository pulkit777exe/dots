import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"











Surface {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: ""

    Layout.fillWidth: true
    implicitHeight: 150
    cornerRadius: 18
    
    
    
    
    backgroundColor: Theme.colors.surface
    borderWidth: 0
    shadow: false

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - 48
        spacing: 8

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            radius: 28
            
            
            
            
            color: Qt.alpha(Theme.colors.accent, 0.18)

            Icon {
                anchors.centerIn: parent
                icon: root.icon
                size: 26
                iconColor: Theme.colors.accent
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.title
            font.pixelSize: 20
            font.weight: Font.DemiBold
            color: Theme.colors.text
            elide: Text.ElideRight
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            text: root.subtitle
            font.pixelSize: 13
            color: Theme.withAlpha(Theme.colors.text, 0.45)
        }
    }
}
