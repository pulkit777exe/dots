import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

// SettingsHeader
// The per-page header card: a centred circular badge, the page title, and a
// one-line description, stacked and horizontally centred, inside a card that
// spans the content width.
//
// Every settings page built this inline as a left-aligned RowLayout (a 56px
// badge at the left, then a two-line column beside it) -- the same eight lines
// copied into eleven files. The references show it centred instead: badge on
// top, title beneath it, subtitle beneath that. One shared component, so the
// five pages that had to change cannot drift apart again.
Surface {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: ""

    Layout.fillWidth: true
    implicitHeight: 150
    cornerRadius: 18
    // Same (16,14,12) as SettingsCard -- measured off 2026-09-20_22-30-18,
    // where the header card and the content cards are indistinguishable in
    // colour. This used to be a lighter 0.035 wash, which read as a separate,
    // lighter plane.
    backgroundColor: Qt.rgba(1, 0.875, 0.75, 0.063)
    borderWidth: 0
    shadow: false

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - 48
        spacing: 8

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            radius: 28
            // Accent at 18%, which is (23,49,41) over the card's (16,14,12) --
            // the reference's badge. Qt.alpha, not Qt.rgba(accent.r, ...):
            // Theme.colors holds hex strings, so those components are
            // undefined and Qt.rgba would render a black disc instead.
            color: Qt.alpha(Theme.colors.accent, 0.18)

            Icon {
                anchors.centerIn: parent
                icon: root.icon
                size: 26
                iconColor: Theme.colors.accent
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.title
            font.pixelSize: 20
            font.weight: Font.DemiBold
            color: "#FFFFFF"
            elide: Text.ElideRight
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            text: root.subtitle
            font.pixelSize: 13
            color: Qt.rgba(1, 1, 1, 0.45)
        }
    }
}
