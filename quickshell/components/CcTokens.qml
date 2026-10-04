import QtQuick
import "../services"


// CcTokens.qml -- the control centre's colours.
//
// ControlCenter.qml used to declare eleven `readonly property color` tokens of
// its own, each with a hardcoded hex. Ten of the eleven matched no palette in
// colors/themes/ at all; the eleventh, `bgCardHover` #282828, matched gruvbox's
// `background` by coincidence. The values were unmistakably gruvbox-flavoured
// warm browns, so on the other five themes the panel painted itself in a colour
// that theme had never heard of, while the two places the file did read the
// theme -- `Theme.colors.accent` and `Theme.colors.accentText` -- showed that
// someone had meant to.
//
// Everything here is read from Theme, so it cannot drift from the palette the
// way a literal can, and nothing here is defined that is not either a palette
// key or an alpha of one. `Theme.surfaceRaised` in Theme.qml is the same move,
// and the ramps below use its `Qt.alpha(colors.x, a)` form rather than
// introducing a second mechanism.
//
// It is a plain QtObject rather than a singleton on purpose: components/ is
// imported as a directory (`import "../components"`), not as a module, and
// adding a qmldir there would change how all seventeen existing primitives
// resolve. One instance per file that uses it, declared as a child.
//
// The eleven names under "the eleven" are the ones ControlCenter.qml already
// used, so the substitution reads as a mapping in a diff. The alpha steps are
// the same fractions of the same colour the greys they replace already were --
// #FFFFFF was 1.00 of white, #777777 was 0.47 -- so the text ladder keeps its
// shape and only its top rung changes, from pure white to the theme's text.

QtObject {
    // --- the eleven tokens the file used to hardcode ------------------------

    // The panel itself. Sibling floating panels (Launcher, ClipboardHistory,
    // AudioSettings, WifiPasswordDialog) all sit on Theme.panelFill; this one
    // had its own brown, and it is the base every other token here is read
    // against.
    readonly property color bgSurface: Theme.colors.background

    // A card on the panel: one step up from `background`, which is what makes
    // it a card. This and bgSurface were the same hex, so every card in the
    // panel was invisible against it and only its border gave it away.
    readonly property color bgCard: Theme.colors.surface

    readonly property color bgCardHover: Theme.colors.surfaceAlt

    // An icon button that is on: an accent wash, the same construction
    // ControlCenter already used for the notification avatar.
    readonly property color bgCardActive: Qt.alpha(Theme.colors.accent, 0.22)

    // A row inside a card, so one step up again from `surface`.
    readonly property color bgItem: Theme.colors.surfaceAlt

    readonly property color bgItemHover: Theme.colors.surfaceElevated

    // The unfilled part of a slider. It has to be *darker* than the card it
    // sits in, and no palette key is darker than `background`, so it is
    // `background` knocked back over the card. (`surfaceMuted` is `background`
    // at 70% and composites to within 1.00:1 of `surface` on four of the six
    // themes -- an invisible track -- so it is not the key for this.)
    readonly property color bgSliderTrack: Qt.alpha(Theme.colors.background, 0.45)

    // The same track, one step deeper, for a slider drawn on a row rather than
    // on a card.
    readonly property color bgSliderTrackCard: Qt.alpha(Theme.colors.background, 0.60)

    // The neutral disc behind an unselected icon. Kept off `surfaceElevated`
    // on purpose: that is `bgItemHover`, and a hovered row must still show its
    // own icon against it.
    readonly property color bgBadgeDim: Qt.alpha(Theme.colors.text, 0.20)

    // A chip that sits still: an unselected scale pill, and the faint discs
    // behind an unselected device/Wi-Fi/Focus icon.
    readonly property color bgPill: Qt.alpha(Theme.colors.text, 0.12)

    // Secondary text: section headings, a subtitle, a percentage. The one of
    // the eleven that is not a palette key -- `textMuted` is, but on horizon
    // and ariadne it sits at 1.75:1 and 1.16:1 against `surface` and
    // disappears, where the grey it replaces held 4.20:1.
    readonly property color textDim: Qt.alpha(Theme.colors.text, 0.48)

    // --- what the sixty-eight stray literals became -------------------------

    // Every `border.color: "#282828"` and the panel's own border. The palettes
    // already carry a hairline border at 10% of the foreground.
    readonly property color borderColor: Theme.colors.border

    // The glyph drawn on top of an accent fill: the volume icon inside a
    // slider's filled part, and the Toggle thumb. All three were #111111 or
    // #000000, which is what `accentText` is for on all six themes.
    readonly property color onAccent: Theme.colors.accentText

    // --- the text ramp -----------------------------------------------------
    // One rung per grey the file spelled out by hand, at the same fraction of
    // the same colour it already was.

    readonly property color textPrimary: Theme.colors.text          // #FFFFFF
    readonly property color textIcon:    Qt.alpha(Theme.colors.text, 0.85)  // #DDDDDD #CCCCCC
    readonly property color textStrong:  Qt.alpha(Theme.colors.text, 0.70)  // #AAAAAA
    readonly property color textMedium:  Qt.alpha(Theme.colors.text, 0.60)  // #999999
    readonly property color textSub:     Qt.alpha(Theme.colors.text, 0.55)  // #888888 #8a8a8a
    readonly property color textFaint:   Qt.alpha(Theme.colors.text, 0.42)  // #666666
    readonly property color textGhost:   Qt.alpha(Theme.colors.text, 0.35)  // #555555
}