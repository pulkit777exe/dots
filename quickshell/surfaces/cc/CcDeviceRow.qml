import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

Rectangle {
    id: row

    property string label: ""
    property string icon: "speaker"
    property bool selected: false

    signal picked()

    Layout.preferredHeight: 40
    radius: 12
    color: area.containsMouse ? Theme.cc.itemHover : Theme.cc.item
    border.color: Theme.cc.border
    border.width: 1
    Behavior on color { ColorAnimation { duration: Config.hover() } }

    RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 12 }
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 29
            Layout.preferredHeight: 29
            radius: width / 2
            color: row.selected ? Theme.accentFor("control-center") : Theme.withAlpha(Theme.colors.text, 0.20)
            Behavior on color { ColorAnimation { duration: Config.hover() } }

            Icon {
                anchors.centerIn: parent
                icon: row.icon
                size: 14
                iconColor: row.selected ? Theme.colors.accentText
                    : Theme.withAlpha(Theme.colors.text, 0.70)
            }
        }

        Label {
            Layout.fillWidth: true
            text: row.label
            font.pixelSize: Theme.px(14)
            color: Theme.colors.text
            elide: Text.ElideRight
        }

        Icon {
            visible: row.selected
            icon: "check"
            size: 14
            iconColor: Theme.accentFor("control-center")
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.picked()
    }
}
