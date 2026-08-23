pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Screen brightness via brightnessctl. No D-Bus on this system,
 * so we wrap the CLI directly. Current device: intel_backlight.
 */
QtObject {
    id: root

    property int brightness: 0     // 0-100 percentage
    property int maxRaw: 0         // raw max from brightnessctl
    property bool available: false

    function setBrightness(pct) {
        const clamped = Math.max(0, Math.min(100, pct))
        brightness = clamped
        setProcess.command = ["brightnessctl", "set", clamped + "%"]
        setProcess.running = true
    }

    function increase(amount) {
        setProcess.command = ["brightnessctl", "set", "+" + amount + "%"]
        setProcess.running = true
        refresh()
    }

    function decrease(amount) {
        setProcess.command = ["brightnessctl", "set", amount + "%-"]
        setProcess.running = true
        refresh()
    }

    function refresh() {
        // maxRaw effectively never changes mid-session, so fetch it once and
        // only re-fetch brightness itself on subsequent refreshes. Running
        // both concurrently every poll (the previous behavior) raced --
        // getProcess divides by maxRaw, and on a slow max fetch maxRaw could
        // still be its initial 0, silently reporting 0% regardless of the
        // real value.
        if (root.maxRaw > 0) {
            getProcess.running = true
        } else {
            maxProcess.running = true   // chains into getProcess via onExited below
        }
    }

    property Process setProcess: Process {}

    property Process getProcess: Process {
        command: ["brightnessctl", "get"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const val = parseInt(line.trim())
                if (!isNaN(val)) {
                    root.brightness = root.maxRaw > 0
                        ? Math.round((val / root.maxRaw) * 100)
                        : 0
                    root.available = true
                }
            }
        }
        onExited: (code) => { if (code !== 0) root.available = false }
    }

    property Process maxProcess: Process {
        command: ["brightnessctl", "max"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const val = parseInt(line.trim())
                if (!isNaN(val)) root.maxRaw = val
            }
        }
        onExited: (code) => { if (code === 0 && root.maxRaw > 0) getProcess.running = true }
    }

    property Timer pollTimer: Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
