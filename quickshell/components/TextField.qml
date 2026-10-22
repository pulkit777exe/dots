import QtQuick
import "../services"

// Single-line entry: app typeface, palette colors, clipped to one line.
// Everything else (echoMode, validator, keys) is set by the caller.
TextInput {
    id: root

    property int textSize: 14

    verticalAlignment: TextInput.AlignVCenter
    font.family: Theme.fontFamily
    font.pixelSize: Theme.px(textSize)
    color: Theme.withAlpha(Theme.colors.text, 0.92)
    selectionColor: Theme.withAlpha(Theme.colors.accent, 0.35)
    clip: true
}
