import QtQuick
import "../services"

Text {
    id: root

    property string variant: "body"
    property color textColor: defaultColor

    readonly property int variantPixelSize: {
        switch (variant) {
            case "clock":           return 15
            case "mediaTitle":      return 13
            case "mediaSubtitle":   return 11
            case "mediaArtist":     return 10
            case "dayLetter":       return 10
            case "dayNumber":
            case "dayNumberActive": return 13
            default:                return 12
        }
    }

    readonly property color defaultColor: {
        switch (variant) {
            case "clock":
            case "mediaTitle":
                return Qt.rgba(1, 1, 1, 0.95)

            case "mediaSubtitle":
                return Qt.rgba(1, 1, 1, 0.65)

            case "mediaArtist":
                return Qt.rgba(1, 1, 1, 0.45)

            case "dayLetter":
                return Qt.rgba(1, 1, 1, 0.4)

            case "dayNumber":
                return Qt.rgba(1, 1, 1, 0.85)

            case "dayNumberActive":
                return Theme.colors.accentText

            default:
                return Qt.rgba(1, 1, 1, 0.9)
        }
    }

    color: textColor

    font.family: "SF Pro Display"
    font.pixelSize: variantPixelSize

    font.weight: {
        switch (variant) {
            case "clock":
            case "mediaTitle":
            case "dayNumberActive":
                return Font.DemiBold

            case "dayLetter":
                return Font.Medium

            default:
                return Font.Normal
        }
    }

    font.letterSpacing:
        variant === "mediaArtist" || variant === "dayLetter" ? 0.6 : 0

    font.capitalization:
        variant === "mediaArtist" || variant === "dayLetter"
            ? Font.AllUppercase
            : Font.MixedCase

    renderType: Text.NativeRendering
    antialiasing: true
}
