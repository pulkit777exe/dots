import QtQuick
import QtQuick.Layouts

import "../components"
import "../services"

// AuthPromptMessage.qml -- the inset under the dialog title: the message the
// program asking for authentication supplied, and the action id it asked
// under.
//
// Both strings come from a live polkit request. services/Auth.qml folds the
// AuthFlow into `pending`, AuthDialog.qml picks the two fields off it and
// passes them in, so this file renders and decides nothing: there is no
// polkit here, nothing to poll, and no default to invent when a request has
// no message.
//
// The two lines are visible independently, and that is deliberate rather than
// defensive: polkit sends an action id for essentially every action and a
// message for most, so a request with only an action id has to render as one
// line and still be an inset. The 21 in the height is this box's own padding
// (11 above, 10 below); the 4 is the gap the action id sits below the message.

Rectangle {
    id: root

    // Both empty means there is nothing to show, and the inset is then a
    // 21px band of background. AuthDialog passes empty strings rather than
    // hiding this, because the request can arrive after the dialog does.
    property string message: ""
    property string actionId: ""

    implicitHeight: messageCol.implicitHeight + 21

    radius: 14

    color: Theme.colors.surface

    ColumnLayout {
        id: messageCol

        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 11
        anchors.bottomMargin: 10

        spacing: 0

        StyledText {
            Layout.fillWidth: true

            visible: root.message.length > 0

            text: root.message

            color: Theme.colors.text

            font.pixelSize: 15
            font.weight: Font.DemiBold

            // Wrap, not elide: a polkit message is the one string in this
            // dialog that cannot be shortened without losing the sentence the
            // program was trying to say. The dialog is 430 wide, so this is
            // the only place a height can grow.
            lineHeight: 1.0

            wrapMode: Text.WordWrap
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 4

            visible: root.actionId.length > 0

            // The action id, in full and elided: it is a debugging aid, not
            // something to read, so it gives up width before the message
            // above it would have to.
            text: root.actionId

            color: Theme.withAlpha(Theme.colors.text, 0.55)

            font.pixelSize: 13

            elide: Text.ElideRight
        }
    }
}
