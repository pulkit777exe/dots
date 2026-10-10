import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

Item {
    id: root

    property string label: ""
    property bool checked: false

    signal toggled(bool value)

    implicitHeight: 44
    Layout.fillWidth: true

    RowLayout {
        anchors.fill: parent
        spacing: 12

        Label {
            Layout.fillWidth: true
            text: root.label
            font.pixelSize: Theme.px(13)
            color: Theme.withAlpha(Theme.colors.text, 0.9)
            elide: Text.ElideRight
        }

        Toggle {
            accent: Theme.accentFor("settings")
            checked: root.checked
            onToggled: (v) => root.toggled(v)
        }
    }
}
