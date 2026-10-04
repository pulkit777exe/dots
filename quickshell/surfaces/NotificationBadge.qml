import QtQuick
import QtQuick.Layouts

import "../components"
import "../services"

// NotificationBadge.qml -- the circle at the left of a toast.
//
// It is a glyph or it is a letter. The rule lives here because it is the only
// place both halves of it can be seen at once: a notification that names its
// own icon gets that, and one that does not gets the first letter of its app
// name, so a toast is never a bare grey disc. Which of the two applies is
// decided by Notification.qml, which knows the source of the entry; this file
// draws whichever it was handed and hides the other.
//
// Both are visible at most once: the Icon is gated on hasGlyph and the letter
// on its negation, which is why neither needs a z or an opacity to keep them
// from overlapping.

Rectangle {
    id: root

    property bool hasGlyph: false
    property string glyph: "notifications"
    property string initial: ""

    property color badgeColor: Theme.colors.surfaceAlt
    property color glyphColor: Theme.colors.accent

    // The layout hints belong to this file rather than to Notification.qml:
    // 37 and VCenter are what make a badge look like a badge, and they are not
    // something a caller should have to know in order to place one correctly.
    Layout.preferredWidth: 37
    Layout.preferredHeight: 37
    Layout.alignment: Qt.AlignVCenter

    radius: width / 2

    color: root.badgeColor

    Icon {
        anchors.centerIn: parent

        visible: root.hasGlyph

        icon: root.glyph
        size: 18

        iconColor: root.glyphColor
    }

    StyledText {
        anchors.centerIn: parent

        visible: !root.hasGlyph && root.initial !== ""

        text: root.initial

        font.family: "SF Pro Display"
        font.pixelSize: 13
        font.weight: Font.DemiBold

        color: root.glyphColor
    }
}
