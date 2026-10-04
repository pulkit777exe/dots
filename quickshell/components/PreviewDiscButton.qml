import QtQuick
import "../services"

// The arranger's stand-in for a 1x1 icon control: a circular disc holding one
// glyph, tinted by `isOn`. Like PreviewStatusPill it renders only -- the
// editor owns the interaction.
Item {
    id: root

    property string iconName: ""
    property bool isOn: false

    implicitWidth: 52
    implicitHeight: 52

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.isOn ? Theme.colors.accent : Theme.withAlpha(Theme.colors.text, 0.055)
    }
    Icon {
        anchors.centerIn: parent
        icon: root.iconName
        size: 21
        iconColor: root.isOn ? Theme.colors.accentText : Theme.withAlpha(Theme.colors.text, 0.8)
    }
}
