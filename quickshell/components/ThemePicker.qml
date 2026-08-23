import QtQuick
import QtQuick.Layouts
import "../core"

/** Image 9: grid of theme cards, each with a live swatch bar + name. Reads
 *  Theme.themeNames/Theme.themes directly -- no separate model needed since
 *  Theme.qml already loaded everything at startup. */
GridLayout {
    Layout.fillWidth: true
    columns: 4
    columnSpacing: 8
    rowSpacing: 8

    Repeater {
        model: Theme.themeNames
        delegate: Rectangle {
            required property string modelData
            readonly property var themeData: Theme.themes[modelData]
            readonly property bool isActive: modelData === Theme.activeName

            Layout.preferredWidth: 80
            Layout.preferredHeight: 64
            radius: 12
            color: themeData ? themeData.colors.bg : Theme.colors.surfaceHover
            border.width: isActive ? 2 : 0
            border.color: themeData ? themeData.colors.accent : Theme.colors.accent

            MouseArea {
                anchors.fill: parent
                onClicked: Theme.setTheme(modelData)
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 6
                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 4
                    radius: 2
                    color: themeData ? themeData.colors.accent : Theme.colors.textMuted
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: modelData
                    color: themeData ? themeData.colors.text : Theme.colors.textMuted
                    font.pixelSize: Theme.fontSize - 4
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
}
