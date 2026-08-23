pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/** Thin wrapper over wpctl. Volume is 0-100 for UI convenience; wpctl itself
 *  works in 0.0-1.0 with an optional overdrive above 1.0 which we intentionally
 *  don't expose here to avoid accidental speaker damage from a slider.
 *
 * Device enumeration via `wpctl status`. NOTE: `wpctl status` output uses
 * box-drawing tree characters (e.g. "│ *   43. Name [vol: 0.55]") that this
 * parser strips before matching -- written against the commonly-documented
 * format, not verified against a live `wpctl` here. If device lists come out
 * empty or misfiled, this parser is the first place to check against your
 * actual `wpctl status` output. */
QtObject {
    id: root

    property int volume: 0
    property bool muted: false
    property int inputVolume: 0
    property bool inputMuted: false
    property var outputs: []   // [{ id, name, active }]
    property var inputs: []    // [{ id, name, active }]
    property string activeOutputName: ""

    function setVolume(pct) {
        const clamped = Math.max(0, Math.min(100, pct))
        volume = clamped
        volumeProcess.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (clamped / 100).toFixed(2)]
        volumeProcess.running = true
    }

    function toggleMute() {
        muteProcess.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        muteProcess.running = true
        muted = !muted
    }

    // Input (microphone) gain -- previously AudioPanel's "Input volume"
    // slider called setVolume() and drove the SPEAKER, not the mic, because
    // no input-targeting function existed at all. These target
    // @DEFAULT_AUDIO_SOURCE@ specifically.
    function setInputVolume(pct) {
        const clamped = Math.max(0, Math.min(100, pct))
        inputVolume = clamped
        inputVolumeProcess.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", (clamped / 100).toFixed(2)]
        inputVolumeProcess.running = true
    }

    function toggleInputMute() {
        inputMuteProcess.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]
        inputMuteProcess.running = true
        inputMuted = !inputMuted
    }

    function setDevice(id) {
        setDeviceProcess.command = ["wpctl", "set-default", String(id)]
        setDeviceProcess.running = true
        refresh()
    }

    function refresh() {
        statusProcess.running = true
        inputStatusProcess.running = true
        deviceProcess.running = true
    }

    property Process volumeProcess: Process {
        onExited: root.refreshOutput()
    }
    property Process muteProcess: Process {
        onExited: root.refreshOutput()
    }
    property Process inputVolumeProcess: Process {
        onExited: root.refreshInput()
    }
    property Process inputMuteProcess: Process {
        onExited: root.refreshInput()
    }
    property Process setDeviceProcess: Process {}

    function refreshOutput() { statusProcess.running = true }
    function refreshInput() { inputStatusProcess.running = true }

    property Process statusProcess: Process {
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const match = line.match(/Volume:\s*([\d.]+)\s*(\[MUTED\])?/)
                if (!match) return
                root.volume = Math.round(parseFloat(match[1]) * 100)
                root.muted = !!match[2]
            }
        }
    }

    property Process inputStatusProcess: Process {
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const match = line.match(/Volume:\s*([\d.]+)\s*(\[MUTED\])?/)
                if (!match) return
                root.inputVolume = Math.round(parseFloat(match[1]) * 100)
                root.inputMuted = !!match[2]
            }
        }
    }

    property Process deviceProcess: Process {
        command: ["wpctl", "status"]
        property string _section: ""
        property var _outputBuffer: []
        property var _inputBuffer: []
        onRunningChanged: if (running) { _section = ""; _outputBuffer = []; _inputBuffer = [] }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                // Strip leading box-drawing tree characters (│ ├ └ ─) and whitespace
                const clean = line.replace(/^[\s│├└─]+/, "").trim()
                if (clean === "") return

                const header = clean.match(/^(Sinks|Sources|Filters|Streams|Devices):\s*$/)
                if (header) {
                    deviceProcess._section = header[1].toLowerCase()
                    return
                }

                // Only Sinks/Sources sections contain audio devices we care
                // about -- Streams/Filters/Devices entries also look like
                // "id. name" and would get misfiled if not excluded here.
                if (deviceProcess._section !== "sinks" && deviceProcess._section !== "sources")
                    return

                const isActive = clean.startsWith("*")
                const deviceLine = clean.replace(/^\*\s*/, "")
                const match = deviceLine.match(/^(\d+)\.\s*(.+?)(?:\s*\[vol:[^\]]*\])?\s*$/)
                if (!match) return

                const entry = { id: parseInt(match[1]), name: match[2].trim(), active: isActive }
                if (deviceProcess._section === "sinks") {
                    deviceProcess._outputBuffer = deviceProcess._outputBuffer.concat([entry])
                    if (isActive) root.activeOutputName = entry.name
                } else {
                    deviceProcess._inputBuffer = deviceProcess._inputBuffer.concat([entry])
                }
            }
        }
        // rebuild from scratch each refresh -- unplugged devices must not linger
        onExited: {
            root.outputs = deviceProcess._outputBuffer
            root.inputs = deviceProcess._inputBuffer
        }
    }

    Component.onCompleted: refresh()
}
