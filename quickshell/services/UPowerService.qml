pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Battery status via UPower D-Bus. Exposes percentage, charging state,
 * and a low-battery flag. Polls every 30s.
 *
 * Device path is discovered via `upower -e` rather than hardcoded --
 * hardcoding battery_BAT1 meant this never worked on the (more common)
 * single-battery laptops that expose BAT0 instead.
 */
QtObject {
    id: root

    property int percentage: 0
    property bool charging: false
    property bool low: percentage < 20 && !charging
    property bool available: false
    property string devicePath: ""

    function refresh() {
        if (devicePath === "") {
            discoverProcess.running = true
        } else {
            percentageProcess.running = true
            stateProcess.running = true
        }
    }

    property Process discoverProcess: Process {
        command: ["upower", "-e"]
        property string _found: ""
        onRunningChanged: if (running) _found = ""
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const trimmed = line.trim()
                if (discoverProcess._found === "" && trimmed.includes("battery_"))
                    discoverProcess._found = trimmed
            }
        }
        onExited: (code) => {
            if (code === 0 && discoverProcess._found !== "") {
                root.devicePath = discoverProcess._found
                percentageProcess.running = true
                stateProcess.running = true
            } else {
                root.available = false
            }
        }
    }

    property Process percentageProcess: Process {
        command: ["busctl", "get-property", "org.freedesktop.UPower",
                  root.devicePath, "org.freedesktop.UPower.Device", "Percentage"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const match = line.match(/d\s+([\d.]+)/)
                if (match) {
                    root.percentage = Math.round(parseFloat(match[1]))
                    root.available = true
                }
            }
        }
        // if the cached path went stale (e.g. battery swapped), fall back to rediscovering
        onExited: (code) => { if (code !== 0) { root.available = false; root.devicePath = "" } }
    }

    property Process stateProcess: Process {
        command: ["busctl", "get-property", "org.freedesktop.UPower",
                  root.devicePath, "org.freedesktop.UPower.Device", "State"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                // State: 1=charging, 2=discharging, 4=fully-charged (plugged
                // in, at 100%) -- treated as "charging" too, since visually
                // it should read as plugged-in, not "on battery".
                const match = line.match(/u\s+(\d+)/)
                if (match) {
                    const state = parseInt(match[1])
                    root.charging = state === 1 || state === 4
                }
            }
        }
    }

    property Timer pollTimer: Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
