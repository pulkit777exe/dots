pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Workspace-aware auto-hide support. Confirmed behavior: the island hides
 * whenever the active workspace has ANY window, and comes back on hover
 * (via the hot-zone in shell.qml) or when the workspace goes empty again.
 *
 * Truth always comes from a full atomic requery (`hyprctl -j clients` +
 * `hyprctl -j activeworkspace`, JSON.parse'd) rather than incrementally
 * tracking deltas from the raw event stream -- incremental tracking is
 * exactly the kind of stateful parsing that caused bugs elsewhere in this
 * tree (see AudioService's device-list history). The event stream
 * (scripts/hypr-watch.sh, tailing Hyprland's socket2) is only used as a
 * "something changed, re-query" trigger, debounced; a periodic poll is a
 * fallback in case socat/hypr-watch isn't available.
 */
QtObject {
    id: root

    property bool activeWorkspaceEmpty: true
    property int windowCount: 0
    property var activeWorkspaceId: null

    property var _lastClients: []

    function refresh() {
        activeWorkspaceProcess.running = true
        clientsProcess.running = true
    }

    function _recompute() {
        if (root.activeWorkspaceId === null) return
        const onWorkspace = root._lastClients.filter(
            c => c.workspace && c.workspace.id === root.activeWorkspaceId
        )
        root.windowCount = onWorkspace.length
        root.activeWorkspaceEmpty = onWorkspace.length === 0
    }

    property Process clientsProcess: Process {
        command: ["hyprctl", "-j", "clients"]
        property string _buffer: ""
        onRunningChanged: if (running) _buffer = ""
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => clientsProcess._buffer += line + "\n"
        }
        onExited: (code) => {
            if (code !== 0) return
            try {
                root._lastClients = JSON.parse(clientsProcess._buffer)
                root._recompute()
            } catch (e) {
                console.warn("HyprlandService: failed to parse `hyprctl -j clients`", e)
            }
        }
    }

    property Process activeWorkspaceProcess: Process {
        command: ["hyprctl", "-j", "activeworkspace"]
        property string _buffer: ""
        onRunningChanged: if (running) _buffer = ""
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => activeWorkspaceProcess._buffer += line + "\n"
        }
        onExited: (code) => {
            if (code !== 0) return
            try {
                const ws = JSON.parse(activeWorkspaceProcess._buffer)
                root.activeWorkspaceId = ws.id
                root._recompute()
            } catch (e) {
                console.warn("HyprlandService: failed to parse `hyprctl -j activeworkspace`", e)
            }
        }
    }

    // live event stream -- any line means "something changed", debounced
    // so a burst of events (e.g. several windows closing at once) triggers
    // one requery, not several.
    property Timer debounceTimer: Timer {
        interval: 80
        onTriggered: root.refresh()
    }

    property Process watchProcess: Process {
        running: true
        command: [Quickshell.shellDir + "/scripts/hypr-watch.sh"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.debounceTimer.restart()
        }
        onExited: (code) => {
            if (code !== 0)
                console.warn("HyprlandService: hypr-watch.sh unavailable (need socat) -- relying on the 3s poll fallback instead")
        }
    }

    // safety net if the live event stream isn't running
    property Timer pollTimer: Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
