import QtQuick
import "../services"

// A Material Symbols glyph. The font renders at pixelSize == size, so the
// whole icon set scales with the font-size setting for free.

Text {
    id: root

    property string icon: ""
    property int size: 16
    property color iconColor: Theme.withAlpha(Theme.colors.text, 0.92)

    text: icon
    color: iconColor
    font.family: "Material Symbols Rounded"
    font.pixelSize: Theme.px(size)

    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
    antialiasing: true

    Behavior on color { ColorAnimation { duration: Config.hover() } }
}
