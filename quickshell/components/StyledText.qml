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

    // Every rung used to be `Qt.rgba(1, 1, 1, a)` -- a fixed fraction of pure
    // white, which is a colour the palette never gets to choose. Each is now
    // the same fraction of `Theme.colors.text`, so the RAMP SHAPE is untouched
    // and only its top rung moves (see CcTokens.qml, which made the same move
    // for the control centre and is the reason these alphas are already the
    // numbers they are).
    readonly property color defaultColor: {
        switch (variant) {
            case "clock":
                // Deliberately NOT sharing a case with `mediaTitle`, which it
                // used to. The two agreed at 0.95 by coincidence -- one is the
                // bar clock, the other is an MPRIS title -- and a shared case
                // label means editing one recolours the other with no diff
                // anywhere near the site that changed. Same value today, two
                // independent rungs from here on.
                return Theme.withAlpha(Theme.colors.text, 0.95)

            case "mediaTitle":
                return Theme.withAlpha(Theme.colors.text, 0.95)

            case "mediaSubtitle":
                return Theme.withAlpha(Theme.colors.text, 0.65)

            case "mediaArtist":
                return Theme.withAlpha(Theme.colors.text, 0.45)

            case "dayLetter":
                return Theme.withAlpha(Theme.colors.text, 0.4)

            case "dayNumber":
                return Theme.withAlpha(Theme.colors.text, 0.85)

            case "dayNumberActive":
                return Theme.colors.accentText

            default:
                return Theme.withAlpha(Theme.colors.text, 0.9)
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
