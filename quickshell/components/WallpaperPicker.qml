import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"

/** Image 10: wallpaper grid, scoped to the ACTIVE theme's wallpaper set
 *  (Theme.wallpapers) -- confirmed: wallpapers never change the palette,
 *  they're purely cosmetic within a theme. */
ColumnLayout {
    Layout.fillWidth: true
    spacing: 8

    Text {
        text: Theme.activeName
        color: Theme.colors.textMuted
        font.pixelSize: Theme.fontSize - 3
        Layout.alignment: Qt.AlignRight
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 3
        columnSpacing: 6
        rowSpacing: 6

        Repeater {
            model: Theme.wallpapers
            delegate: Rectangle {
                required property string modelData
                Layout.preferredWidth: 100
                Layout.preferredHeight: 64
                radius: 8
                color: Theme.colors.surfaceHover
                border.width: 2
                border.color: "transparent"

                Image {
                    anchors.fill: parent
                    anchors.margins: 2
                    source: Quickshell.shellDir + "/wallpapers/" + modelData
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Theme.applyWallpaper(modelData)
                }
            }
        }

        Text {
            visible: Theme.wallpapers.length === 0
            text: "No wallpapers registered for this theme yet -- add entries under \"wallpapers\" in themes/" + Theme.activeName + ".json"
            color: Theme.colors.textMuted
            font.pixelSize: Theme.fontSize - 4
            font.italic: true
            wrapMode: Text.WordWrap
            Layout.columnSpan: 3
            Layout.fillWidth: true
        }
    }
}
