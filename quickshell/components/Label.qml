import QtQuick
import "../services"

Text {
    id: root

    font.family: Theme.fontFamily
    color: Theme.withAlpha(Theme.colors.text, 0.9)
    renderType: Text.NativeRendering
    antialiasing: true
}
