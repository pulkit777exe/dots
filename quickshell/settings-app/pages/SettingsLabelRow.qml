import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

Label {
    property string label: ""

    Layout.fillWidth: true
    text: label
    font.pixelSize: Theme.px(11)
    color: Theme.withAlpha(Theme.colors.text, 0.48)
}
