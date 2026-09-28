import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

// SettingsSectionLabel
// The small caption that sits *between* two cards, naming the group below it
// -- "Game mode" on the Bar & Island page, "VOLUME / BRIGHTNESS OSD" on
// Notifications. It lives outside any card because it labels a section, not a
// row.
//
// upperCase picks the two treatments the references actually use: Bar & Island
// writes its caption in sentence case, Notifications sets it in spaced caps.
// Both are the same size, weight and colour; only the casing differs.
StyledText {
    id: root

    property string label: ""
    property bool upperCase: false

    Layout.fillWidth: true
    Layout.leftMargin: 4
    // The reference's clear gap between the first card's bottom edge and the
    // second card's top edge is 35px (2026-09-20_22-30-13: 583 -> 618), with
    // the caption's ink at 596..605 -- 13px of space either side of the glyphs.
    // The page's own spacing is 12 and this label's line box measures 27, so
    // -2 top and bottom is what closes the remaining 12px. It was +4/+4,
    // which left a 47px gap.
    Layout.topMargin: -2
    Layout.bottomMargin: -2
    font.pixelSize: 11
    font.weight: Font.DemiBold
    font.letterSpacing: upperCase ? 1.0 : 0.0
    font.capitalization: upperCase ? Font.AllUppercase : Font.MixedCase
    text: root.label
    textColor: Qt.rgba(1, 1, 1, 0.4)
}
