pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/** Thin wrapper over bluetoothctl. Same shape as NetworkService on purpose --
 *  both are "list of devices + connect/toggle", keep the pattern consistent
 *  rather than inventing a new shape per service.
 *
 * Connection status is a real check now (was hardcoded false before): paired
 * devices come from one call, currently-connected MACs from a second, then
 * merged. Two calls beats N+1 `bluetoothctl info <mac>` calls per device. */
QtObject {
    id: root

    property bool enabled: false
    property var devices: []   // [{ name, mac, connected }]
    property bool scanning: false

    property var _pairedBuffer: []
    property var _connectedMacs: ({})

    function refresh() {
        scanning = true
        _pairedBuffer = []
        _connectedMacs = ({})
        pairedProcess.running = true
        powerQueryProcess.running = true
    }

    property Process powerQueryProcess: Process {
        command: ["bluetoothctl", "show"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const trimmed = line.trim()
                if (trimmed.startsWith("Powered:")) {
                    root.enabled = trimmed.endsWith("yes")
                }
            }
        }
    }

    function setEnabled(on) {
        enabled = on
        powerProcess.command = ["bluetoothctl", "power", on ? "on" : "off"]
        powerProcess.running = true
    }

    function connectTo(mac) {
        connectProcess.command = ["bluetoothctl", "connect", mac]
        connectProcess.running = true
    }

    property Process pairedProcess: Process {
        command: ["bluetoothctl", "devices", "Paired"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const match = line.match(/^Device\s+([0-9A-Fa-f:]{17})\s+(.+)$/)
                if (!match) return
                const [, mac, name] = match
                root._pairedBuffer = root._pairedBuffer.concat([{ name: name, mac: mac }])
            }
        }
        onExited: connectedProcess.running = true
    }

    property Process connectedProcess: Process {
        command: ["bluetoothctl", "devices", "Connected"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const match = line.match(/^Device\s+([0-9A-Fa-f:]{17})\s+/)
                if (!match) return
                const merged = Object.assign({}, root._connectedMacs)
                merged[match[1]] = true
                root._connectedMacs = merged
            }
        }
        onExited: {
            root.devices = root._pairedBuffer.map(d => ({
                name: d.name, mac: d.mac, connected: !!root._connectedMacs[d.mac]
            }))
            root.scanning = false
        }
    }

    property Process powerProcess: Process {}
    property Process connectProcess: Process {
        onExited: (code) => { if (code === 0) root.refresh() }
    }

    property Timer pollTimer: Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
