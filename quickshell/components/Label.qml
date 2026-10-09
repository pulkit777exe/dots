import QtQuick
import "../services"

Text {
    id: root

    font.family: "SF Pro Display"
    color: Theme.withAlpha(Theme.colors.text, 0.9)
    renderType: Text.NativeRendering
    antialiasing: true
}
