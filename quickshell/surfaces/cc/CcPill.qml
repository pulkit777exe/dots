import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

Rectangle {
    id: pill

    property bool active: false
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property color accent: Theme.accentFor("control-center")

    signal clicked()

    height: 57
    radius: 16
    color: area.containsMouse ? Theme.cc.cardHover : Theme.cc.card
    border.color: Theme.cc.border
    border.width: 1

    Behavior on color { ColorAnimation { duration: Config.hover() } }

    scale: area.pressed ? 0.97 : 1.0
    Behavior on scale {
        enabled: !Config.reduceMotion
        SpringAnimation { spring: 6; damping: Config.springDamping; mass: 0.4 }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 9
        anchors.rightMargin: 11
        spacing: 9

        Rectangle {
            width: 41
            height: 41
            radius: width / 2
            Layout.alignment: Qt.AlignVCenter
            color: pill.active ? pill.accent : Theme.withAlpha(Theme.colors.text, 0.12)
            Behavior on color { ColorAnimation { duration: Config.hover() } }

            Icon {
                anchors.centerIn: parent
                icon: pill.icon
                size: 20
                iconColor: pill.active ? Theme.colors.accentText : Theme.withAlpha(Theme.colors.text, 0.85)
            }
        }

        ColumnLayout {
            spacing: 1
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            Label {
                Layout.fillWidth: true
                text: pill.title
                font.pixelSize: Theme.px(13)
                font.weight: Font.Bold
                color: Theme.colors.text
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                visible: pill.subtitle.length > 0
                text: pill.subtitle
                font.pixelSize: Theme.px(11)
                color: Theme.withAlpha(Theme.colors.text, 0.55)
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.clicked()
    }
}
