import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

// One bluetooth device row: badge, name + state, and the one action the
// state implies (pair / connect / disconnect).

Rectangle {
    id: row

    property var device: ({})
    signal action()

    Layout.preferredHeight: 46
    radius: 12
    color: area.containsMouse ? Theme.cc.itemHover : Theme.cc.item
    border.color: device.connected ? Theme.accentFor("control-center") : Theme.cc.border
    border.width: 1
    Behavior on color { ColorAnimation { duration: Config.hover() } }

    readonly property bool connected: !!device.connected
    readonly property bool paired: !!device.paired

    RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 12 }
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: width / 2
            color: row.connected ? Theme.accentFor("control-center") : Theme.withAlpha(Theme.colors.text, 0.12)
            Behavior on color { ColorAnimation { duration: Config.hover() } }

            Icon {
                anchors.centerIn: parent
                icon: row.paired ? "headphones" : "bluetooth"
                size: 15
                iconColor: row.connected ? Theme.colors.accentText
                    : Theme.withAlpha(Theme.colors.text, 0.70)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Label {
                Layout.fillWidth: true
                text: row.device.name || row.device.mac || ""
                font.pixelSize: Theme.px(12)
                color: Theme.colors.text
                elide: Text.ElideRight
            }
            Label {
                text: row.connected ? "Connected" : (row.paired ? "Saved" : "Not paired")
                font.pixelSize: Theme.px(11)
                color: Theme.withAlpha(Theme.colors.text, 0.48)
            }
        }

        Label {
            text: row.connected ? "Disconnect" : (row.paired ? "Connect" : "Pair")
            font.pixelSize: Theme.px(11)
            color: Theme.accentFor("control-center")
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.action()
    }
}
