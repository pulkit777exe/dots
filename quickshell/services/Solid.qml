// services/Solid.qml
//
// The "solid" surface chrome shared by every panel, card and row in the
// shell. This is deliberately NOT the theme palette.
//
// Looking at the panels: the chrome stays a near-black layering system in
// every theme, and only the accent moves. That is the design — a theme
// change recolours the highlights, it does not repaint the furniture. So
// these greys are fixed on purpose, and they live here so there is exactly
// one definition of them.
//
// Before this existed the same values were copy-pasted: ControlCenter.qml
// declared its own copy inline, MediaPlayerSurface.qml invented a slightly
// different set, and Island/Calendar hardcoded a Catppuccin Latte cream
// (#F7EFE1) that looked wrong under every other theme. Import this instead
// of writing hex literals.
//
// Text and semantic colours are the exception — those come from Theme, so
// they follow the palette. Use fg()/onAccent() rather than Qt.rgba(1,1,1,a):
// a fixed white overlay disappears on a light theme.

import QtQuick

pragma Singleton

Singleton {
    id: root

    // ---- Surface layering -----------------------------------------
    // Panel background, then progressively raised surfaces.
    readonly property color bgSurface: "#141414"
    readonly property color bgCard: "#1f1f1f"
    readonly property color bgCardHover: "#282828"
    readonly property color bgCardActive: "#24332c"
    readonly property color bgItem: "#242424"
    readonly property color bgItemHover: "#2e2e2e"
    readonly property color bgSliderTrack: "#2c2c2c"

    // Hairline separators and panel outlines.
    readonly property color borderSubtle: "#262626"
    readonly property color borderFaint: Qt.rgba(1, 1, 1, 0.08)

    // ---- Geometry -------------------------------------------------
    // Radii observed across the panels: big on the outer surface, smaller
    // on cards and rows, fully rounded on pills.
    readonly property int radiusPanel: 24
    readonly property int radiusCard: 14
    readonly property int radiusRow: 10
    readonly property int radiusBadge: 999

    // ---- Theme-derived helpers -------------------------------------
    // Foreground at a given opacity, following the active palette instead
    // of assuming white.
    function fg(a) {
        const c = Theme.colors.foreground;
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // Muted foreground, for secondary labels and hints.
    function muted(a) {
        const c = Theme.colors.muted;
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // Readable text on top of an accent-filled element.
    function onAccent() {
        return Theme.colors.accentText;
    }

    // Semantic colours. Sunday/weekend markers, error states and so on
    // used to be literal #E05252 reds that ignored the palette.
    readonly property color danger: Theme.colors.error
    readonly property color warning: Theme.colors.warning
    readonly property color success: Theme.colors.success

    // Convenience mirrors so a surface can pull everything from one place.
    readonly property color accent: Theme.colors.accent
    readonly property color accentText: Theme.colors.accentText
}
