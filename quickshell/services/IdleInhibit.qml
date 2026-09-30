pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io










Singleton {
    id: root

    property bool active: false

    function toggle() { active = !active }

    Process {
        id: inhibitor
        running: root.active
        command: ["systemd-inhibit", "--what=idle:sleep", "--why=Quickshell keep-awake", "--mode=block", "sleep", "infinity"]
        onExited: (code, status) => {
            
            
            
            if (root.active) root.active = false
        }
    }
}
