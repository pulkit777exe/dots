import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../services"

/**
 * One row in the Control Center's toggle grid (Image 2).
 * Each tile has an icon + label + sublabel. The whole tile is tappable.
 */
Rectangle {
    id: root
    property string label: ""
    property string sublabel: ""
    property string icon: ""
    property bool active: false
    signal tap()

    Layout.fillWidth: true
    implicitHeight: 56
    radius: 14
    color: active ? Theme.colors.accent : Theme.colors.surfaceHover

    Behavior on color { ColorAnimation { duration: Config.animNormal } }

    MouseArea {
        anchors.fill: parent
        onClicked: root.tap()
    }

    RowLayout {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        spacing: 8

        Text {
            text: root.icon
            color: root.active ? Theme.colors.bg : Theme.colors.accent
            font.family: Config.iconFontFamily
            font.pixelSize: Config.iconSizeNormal
        }

        ColumnLayout {
            spacing: 1
            Text {
                text: root.label
                color: root.active ? Theme.colors.bg : Theme.colors.text
                font.pixelSize: Theme.fontSize - 1
                font.bold: true
            }
            Text {
                text: root.sublabel
                color: root.active ? Theme.colors.bg : Theme.colors.textMuted
                font.pixelSize: Theme.fontSize - 4
                elide: Text.ElideRight
                Layout.maximumWidth: 120
            }
        }
    }
}
