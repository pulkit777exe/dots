import QtQuick
import "../services"

// The shell's text style: one family, native rendering, sizes always via
// Theme.px() at the call site so the font-size setting reaches them.

Text {
    id: root

    font.family: "SF Pro Display"
    color: Theme.withAlpha(Theme.colors.text, 0.9)
    renderType: Text.NativeRendering
    antialiasing: true
}
