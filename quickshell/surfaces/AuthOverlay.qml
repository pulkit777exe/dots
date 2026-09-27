import QtQuick
import "../components"
import "../services"

Item {
    id: root

    anchors.fill: parent

    visible: !!Auth.pending

    // Keep the overlay above everything in this window.
    z: 1000

    focus: visible

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

    onVisibleChanged: {
        if (visible)
            forceActiveFocus()
    }
}