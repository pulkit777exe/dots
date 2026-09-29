import QtQuick
import "../components"
import "../services"

Item {
    id: root

    anchors.fill: parent

    visible: !!Auth.pending

    // Keep the overlay above everything in this window.
    z: 1000

    // Deliberately does NOT take focus, and does not call forceActiveFocus()
    // when it becomes visible.
    //
    // It used to do both (`focus: visible` plus forceActiveFocus() in
    // onVisibleChanged), and that is why the password field could not be typed
    // into. AuthDialog's TextInput sets `focus: true` and also
    // forceActiveFocus()es itself from its own onVisibleChanged and from
    // Auth.requestBegan, but this overlay's visible change fires in the same
    // pass and claimed focus for the plain Item that is its parent -- taking
    // it straight back off the field. With the field unfocused the TextInput
    // never became the active focus item, so keystrokes went to whatever else
    // had Wayland focus (the terminal) and the dialog sat there looking
    // perfectly normal while ignoring the keyboard.
    //
    // Measured with a stubbed Auth.pending and a probe on the field, before
    // the fix: activeFocus=false, and typing 6 characters left textLen=0.
    // After: activeFocus=true as soon as the dialog shows, and all 6
    // characters land. The window above already takes
    // WlrKeyboardFocus.Exclusive whenever Auth.pending is non-null, so the
    // keys do reach this surface -- the item focus was the only thing wrong.

    Scrim {
        anchors.fill: parent

        dismissOnClick: false
    }

    AuthDialog {
        anchors.centerIn: parent

        onAuthenticateRequested: function(password) {
            Auth.respond(password)
        }

        onCancelled: function() {
            Auth.cancel()
        }
    }
}