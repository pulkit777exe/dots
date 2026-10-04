import QtQuick
import QtQuick.Layouts
import "../services"

// The arranger's stand-in for a status control: a rounded pill with an
// accentable icon disc, a title and a subtitle. Nothing here is interactive
// -- the editor draws a MouseArea over the whole slot -- so this is a pure
// rendering primitive. Which singleton backs `isOn` is the dispatcher's
// problem (ControlPreview), not this file's.
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property string iconName: ""

    property bool isOn: false
    property bool showSubtitle: true

    implicitHeight: 52
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.withAlpha(Theme.colors.text, 0.055)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 16
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: 18

            color: root.isOn ? Theme.colors.accent : Theme.withAlpha(Theme.colors.text, 0.07)

            Icon {
                anchors.centerIn: parent
                icon: root.iconName
                size: 19
                iconColor: root.isOn ? Theme.colors.accentText : Theme.withAlpha(Theme.colors.text, 0.75)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.colors.text
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.showSubtitle
                text: root.subtitle
                font.pixelSize: 11
                textColor: Theme.withAlpha(Theme.colors.text, 0.55)
                elide: Text.ElideRight
            }
        }
    }
}
