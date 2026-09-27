pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// IdleInhibit — "Keep Awake" quick toggle.
//
// Holds a systemd-inhibit lock (idle:sleep) for as long as `active` is
// true. This is the real, standard, distro-agnostic way to block idle/
// sleep from userspace — no polkit, no root, no compositor-specific
// API. Starting the process takes the lock; setting `running: false`
// sends it SIGTERM, which releases the lock immediately (systemd-inhibit
// only holds the lock for as long as the child process it wraps is
// alive).
Singleton {
    id: root

    property bool active: false

    function toggle() { active = !active }

    Process {
        id: inhibitor
        running: root.active
        command: ["systemd-inhibit", "--what=idle:sleep", "--why=Quickshell keep-awake", "--mode=block", "sleep", "infinity"]
        onExited: (code, status) => {
            // If systemd-inhibit itself isn't available, the process
            // exits immediately rather than holding — reflect that back
            // instead of showing a toggle that silently does nothing.
            if (root.active) root.active = false
        }
    }
}
