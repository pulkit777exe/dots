pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Night Light (blue light filter) via wlsunset.
 * Starts/stops the wlsunset process. Temperature range: 2700K (warm) to 6500K (day).
 * Location defaults to Jaipur, Rajasthan for sunset calculation.
 */
QtObject {
    id: root

    property bool enabled: false
    property real warmTemp: 2700
    property real dayTemp: 6500

    function toggle() {
        if (enabled) stop()
        else start()
    }

    function start() {
        if (enabled) return
        startProcess.running = true
        enabled = true
    }

    function stop() {
        if (!enabled) return
        stopProcess.running = true
        enabled = false
    }

    property Process startProcess: Process {
        command: ["wlsunset", "-l", "26.91", "-L", "75.79",
                  "-t", String(root.warmTemp), "-T", String(root.dayTemp)]
        // Detached — runs as background process
        onExited: (code) => {
            // wlsunset runs continuously once launched, so onExited firing
            // quickly (rather than only when the user later calls stop())
            // means it never actually started -- correct the optimistic
            // `enabled = true` set in start() below.
            if (code !== 0) root.enabled = false
        }
    }

    property Process stopProcess: Process {
        command: ["pkill", "wlsunset"]
    }

    Component.onCompleted: {
        // Check if wlsunset is already running
        checkProcess.running = true
    }

    property Process checkProcess: Process {
        command: ["pgrep", "-x", "wlsunset"]
        property bool _found: false
        onRunningChanged: if (running) _found = false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (line.trim() !== "") checkProcess._found = true
            }
        }
        onExited: root.enabled = checkProcess._found
    }

    property Timer pollTimer: Timer {
        interval: 20000
        running: true
        repeat: true
        onTriggered: checkProcess.running = true
    }
}
