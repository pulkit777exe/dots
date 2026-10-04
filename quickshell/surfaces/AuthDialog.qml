import QtQuick
import QtQuick.Layouts

import "../components"
import "../services"

// AuthDialog.qml -- the polkit authentication prompt.
//
// What is in this file is the dialog: its size, the four strings it reads off
// the pending request, and how those strings and the two buttons are arranged.
// That is all. Three pieces of it each have a file of their own, because each
// is a separate thing to change and each would otherwise be a lump in the
// middle of a layout:
//
//   AuthPromptMessage.qml  the inset: the request's message and action id
//   AuthPasswordField.qml  the box, its label, and getting the caret into it
//   AuthActions.qml        Cancel and Authenticate
//
// Everything to do with polkit itself lives in services/Auth.qml: the agent,
// the flow, and the `pending` record. This file reads `pending` and answers
// with a password; it never calls submit() or cancelAuthenticationRequest()
// directly. AuthOverlay.qml is the only thing in the tree that does that, and
// it does it from the two signals below -- so those two signals are this file's
// public API and are wired from a file that is not this one to change. They
// stay exactly as they were, names and payload.
//
// The measurement contract with the overlay: AuthOverlay centres this, so the
// height is content plus a fixed band rather than a number. 430 wide, and the
// +31 is the padding around the column below.

Surface {
    id: root

    width: 430
    implicitHeight: column.implicitHeight + 31

    cornerRadius: 26

    backgroundColor: Theme.colors.background

    property color accent: Theme.colors.accent

    readonly property var pendingRequest: Auth.pending

    readonly property string dialogTitle: "Authentication required"

    // Every field is defaulted: `pending` is null whenever there is no request,
    // and this dialog is constructed once when the shell loads rather than per
    // request, so the empty-prompt state is the state it starts in.
    readonly property string message:
        pendingRequest ? pendingRequest.message : ""

    readonly property string actionId:
        pendingRequest ? pendingRequest.actionId : ""

    readonly property string errorText:
        pendingRequest ? pendingRequest.errorText : ""

    signal authenticateRequested(string password)
    signal cancelled()

    // A new request, not a new dialog: clear whatever was typed for the last
    // one and take the caret back. Polkit retries a wrong password against the
    // SAME AuthFlow rather than raising a new request, so this also fires on
    // the retry -- which is why the field is emptied rather than kept.
    //
    // callLater, not direct: shell.qml gives the overlay window keyboard focus
    // in the same change that raises this dialog, and a forceActiveFocus()
    // issued before the window holds it is discarded.
    Connections {
        target: Auth

        function onRequestBegan() {
            passwordField.text = ""

            Qt.callLater(function() {
                passwordField.focusInput()
            })
        }
    }

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.leftMargin: 15
        anchors.rightMargin: 15
        anchors.topMargin: 14
        anchors.bottomMargin: 15

        spacing: 0

        RowLayout {
            Layout.fillWidth: true

            Layout.preferredHeight: 30

            spacing: 13

            Rectangle {
                Layout.preferredWidth: 29
                Layout.preferredHeight: 29

                radius: width / 2

                color: root.accent

                Icon {
                    anchors.centerIn: parent

                    icon: "lock"
                    size: 16

                    iconColor: Theme.colors.accentText
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                text: root.dialogTitle

                font.pixelSize: 18
                font.weight: Font.DemiBold

                color: Theme.colors.text

                // A fixed string, so this cannot currently elide. It is here
                // rather than absent because the title is a property: the day
                // it stops being fixed, this is what stops the row overflowing
                // rather than the button being pushed off the dialog.
                elide: Text.ElideRight
            }
        }

        AuthPromptMessage {
            Layout.fillWidth: true
            Layout.topMargin: 10
            Layout.bottomMargin: 12

            message: root.message
            actionId: root.actionId
        }

        AuthPasswordField {
            id: passwordField

            Layout.fillWidth: true

            // The caret logic is in the field; all it needs to know is that
            // something is waiting to be answered.
            active: Boolean(root.pendingRequest)

            labelVisible:
                root.message.length > 0 ||
                root.actionId.length > 0

            // Enter in the box and the Authenticate button are the same
            // request, so both land on one line here rather than each reaching
            // for the field.
            onSubmitted: root.authenticateRequested(
                passwordField.text
            )
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 6

            visible: root.errorText.length > 0

            // polkit's own words: `errorText` is supplementaryMessage when
            // supplementaryIsError is set (services/Auth.qml), which is the
            // agent's explanation of why the last attempt was refused. Shown
            // verbatim, in danger, above the buttons that retry it.
            text: root.errorText

            color: Theme.colors.danger

            font.pixelSize: 12

            wrapMode: Text.WordWrap
        }

        AuthActions {
            Layout.fillWidth: true
            Layout.topMargin: 11

            accent: root.accent

            onCancelPressed: root.cancelled()

            onAuthenticatePressed: root.authenticateRequested(
                passwordField.text
            )
        }
    }
}
