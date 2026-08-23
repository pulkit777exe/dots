pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Thin wrapper over nmcli. Exposes a flat list of visible networks and the
 * currently-connected SSID, refreshed on demand (call refresh()) rather than
 * polling, since a wifi scan is not free.
 */
QtObject {
    id: root

    property bool wifiEnabled: true
    property string activeSsid: ""
    property var networks: []   // [{ ssid, signal, connected, secured }]
    property bool scanning: false

    function refresh() {
        scanning = true
        scanProcess.running = true
    }

    function setWifiEnabled(enabled) {
        wifiEnabled = enabled
        toggleProcess.command = ["nmcli", "radio", "wifi", enabled ? "on" : "off"]
        toggleProcess.running = true
    }

    function connectTo(ssid) {
        connectProcess.command = ["nmcli", "device", "wifi", "connect", ssid]
        connectProcess.running = true
    }

    property Process scanProcess: Process {
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,ACTIVE,SECURITY", "device", "wifi", "list"]
        property var _buffer: []
        onRunningChanged: if (running) _buffer = []
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (!line.trim()) return
                // Split on ':' that ISN'T preceded by a backslash (nmcli's
                // terse-mode escaping), then unescape \: and \\ within each field.
                const parts = line.split(/(?<!\\):/).map(p => p.replace(/\\:/g, ":").replace(/\\\\/g, "\\"))
                if (parts.length < 3) return
                const [ssid, signal, active] = parts
                if (!ssid) return
                scanProcess._buffer = scanProcess._buffer.concat([{
                    ssid: ssid,
                    signal: parseInt(signal) || 0,
                    connected: active === "yes",
                    secured: (parts[3] || "") !== "" && parts[3] !== "--"
                }])
            }
        }
        onExited: {
            // Rebuild from scratch each scan rather than merging into the old
            // list -- otherwise networks that go out of range never leave,
            // and a disconnected activeSsid never clears.
            root.networks = scanProcess._buffer
            const active = scanProcess._buffer.find(n => n.connected)
            root.activeSsid = active ? active.ssid : ""
            root.scanning = false
        }
    }

    property Process toggleProcess: Process {}
    property Process connectProcess: Process {
        onExited: (code) => { if (code === 0) root.refresh() }
    }

    Component.onCompleted: refresh()
}
