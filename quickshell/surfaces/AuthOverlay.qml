import QtQuick
import "../components"
import "../services"

Item {
    id: root

    anchors.fill: parent

    visible: !!Auth.pending

    
    z: 1000

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

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