import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

RowLayout {
    id: header

    property string title: ""
    property bool toggleVisible: false
    property bool toggleOn: false

    signal back()
    signal toggled()

    spacing: 12

    Rectangle {
        Layout.preferredWidth: 23
        Layout.preferredHeight: 23
        radius: width / 2
        color: backArea.containsMouse ? Theme.cc.itemHover : Theme.cc.item
        border.color: Theme.cc.border
        border.width: 1
        Behavior on color { ColorAnimation { duration: Config.hover() } }

        Icon {
            anchors.centerIn: parent
            icon: "chevron_left"
            size: 14
            iconColor: Theme.withAlpha(Theme.colors.text, 0.85)
        }
        MouseArea {
            id: backArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: header.back()
        }
    }

    Label {
        Layout.fillWidth: true
        text: header.title
        font.pixelSize: Theme.px(18)
        font.weight: Font.DemiBold
        color: Theme.colors.text
        elide: Text.ElideRight
    }

    Toggle {
        accent: Theme.accentFor("control-center")
        visible: header.toggleVisible
        checked: header.toggleOn
        onToggled: header.toggled()
    }
}
