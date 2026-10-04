import QtQuick
import QtQuick.Layouts

import "../components"
import "../services"

// NotificationText.qml -- the three lines of a toast: who sent it, what it is
// called, and what it says.
//
// The strings arrive already chosen. `headline` is the title if the source had
// one and the summary otherwise, and `body` is the subtitle or the body -- a
// fallback chain like that is a question about the *entry*, and the entry is
// Notification.qml's to interpret; doing it here too would mean two places to
// change the next time a source grows a title.
//
// The heights are fixed and the third line is positioned rather than stacked,
// so a toast with no body is exactly 14px shorter instead of leaving an empty
// line's worth of gap. That is why `implicitHeight` is the only height here:
// the toast's own height is this column's implicit height plus its padding,
// and a body is worth 44 rather than 30.

Item {
    id: root

    Layout.fillWidth: true
    Layout.alignment: Qt.AlignVCenter

    property string appName: ""
    property string headline: ""
    property string body: ""

    readonly property bool hasBody: root.body.length > 0

    implicitHeight: hasBody ? 44 : 30

    StyledText {
        width: parent.width
        height: 12

        verticalAlignment: Text.AlignVCenter

        // "Notification", not "": a toast with no sender is still a toast, and
        // an unattributed first line reads as a rendering fault.
        text:
            root.appName ||
            "Notification"

        textColor: Theme.withAlpha(Theme.colors.text, 0.55)

        font.pixelSize: 12
        font.weight: Font.Medium

        elide: Text.ElideRight
    }

    StyledText {
        width: parent.width
        height: 16
        y: 14

        verticalAlignment: Text.AlignVCenter

        text: root.headline

        textColor: Theme.colors.text

        font.pixelSize: 14
        font.weight: Font.DemiBold

        elide: Text.ElideRight
    }

    StyledText {
        width: parent.width
        height: 14
        y: 30

        verticalAlignment: Text.AlignVCenter

        visible: root.hasBody

        text: root.body

        textColor: Theme.withAlpha(Theme.colors.text, 0.55)

        font.pixelSize: 11

        elide: Text.ElideRight
    }
}
