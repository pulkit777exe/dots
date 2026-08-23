import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

/** Image 4: transient notification toast. Reads NotificationService.newest,
 *  shares the same data model as the persistent list in ControlCenter. */
Rectangle {
    id: root
    property var notification: NotificationService.newest

    implicitWidth: 320
    implicitHeight: col.implicitHeight + 24
    radius: 18
    color: Theme.colors.surface
    border.width: 1
    border.color: Qt.lighter(Theme.colors.surface, 1.3)
    visible: notification !== null

    MouseArea {
        anchors.fill: parent
        onClicked: IslandState.openExpanded()
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 12
        spacing: 4

        RowLayout {
            spacing: 8
            Rectangle {
                width: 20; height: 20; radius: 10
                color: Theme.colors.accent
                Text { anchors.centerIn: parent; text: "i";                 color: Theme.colors.bg; font.bold: true; font.pixelSize: 11; font.family: Theme.fontFamily }
            }
            Text {
                text: root.notification ? root.notification.appName : ""
                color: Theme.colors.textMuted
                font.pixelSize: Theme.fontSize - 3
                font.family: Theme.fontFamily
            }
        }
        Text {
            text: root.notification ? root.notification.summary : ""
            color: Theme.colors.text
            font.pixelSize: Theme.fontSize
            font.bold: true
            font.family: Theme.fontFamily
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        Text {
            text: root.notification ? root.notification.body : ""
            color: Theme.colors.textMuted
            font.pixelSize: Theme.fontSize - 2
            font.family: Theme.fontFamily
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }
}
