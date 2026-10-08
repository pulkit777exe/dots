pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io

// The now-playing card's data: one active player, picked as "anything
// playing, else the last one seen".
//
// Position: MPRIS players report position sporadically, so the ticker
// self-increments while playing and re-syncs from playerctl every 2.5s --
// trusting the native value only when it disagrees by more than 2s.

Singleton {
    id: root

    property MprisPlayer active: null
    readonly property bool hasPlayer: active !== null

    readonly property string title: active ? (active.trackTitle || "") : ""
    readonly property string artist: active ? (active.trackArtist || "") : ""
    readonly property bool playing: active ? active.isPlaying : false
    readonly property bool canTogglePlaying: active ? active.canTogglePlaying : false

    readonly property string artUrl: {
        if (!active) return "";
        if (active.trackArtUrl && active.trackArtUrl.length > 0) return active.trackArtUrl;
        const meta = active.metadata || {};
        return meta["mpris:artUrl"] || "";
    }

    readonly property real length: {
        if (!active) return 0;
        if (active.length && active.length > 0) return active.length;
        const meta = active.metadata || {};
        const micros = meta["mpris:length"] || 0;
        return micros > 0 ? micros / 1000000 : 0;
    }

    property real position: 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

    // Repick the active player whenever the set changes or something starts.
    function repick() {
        const players = Mpris.players.values;
        if (players.length === 0) { active = null; position = 0; return; }
        const playingOne = players.find(p => p.isPlaying);
        active = playingOne || players[players.length - 1];
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() { root.repick(); }
    }
    onActiveChanged: {
        if (active) {
            const native = active.position;
            position = (!isNaN(native) && native > 0) ? native : 0;
        } else {
            position = 0;
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: root.playing && root.hasPlayer
        onTriggered: {
            const native = root.active.position;
            if (!isNaN(native) && native > 0 && Math.abs(native - root.position) > 2)
                root.position = native;
            else if (root.length === 0 || root.position < root.length)
                root.position = Math.min(root.length || Infinity, root.position + 0.5);
        }
    }

    Timer {
        interval: 2500
        repeat: true
        running: root.playing && root.hasPlayer
        onTriggered: posProc.running = true
    }

    Process {
        id: posProc
        command: ["playerctl", "position"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat((text || "").trim());
                if (!isNaN(v) && v >= 0) root.position = v;
            }
        }
    }

    function togglePlay() {
        if (active && active.canTogglePlaying) active.togglePlaying();
    }
    function next() {
        if (active && active.canGoNext) active.next();
        else Quickshell.execDetached(["playerctl", "next"]);
    }
    function previous() {
        if (active && active.canGoPrevious) active.previous();
        else Quickshell.execDetached(["playerctl", "previous"]);
    }
    function stop() {
        if (active) active.stop();
        else Quickshell.execDetached(["playerctl", "stop"]);
    }

    IpcHandler {
        target: "mpris"
        function toggle(): void { root.togglePlay(); }
        function play(): void { root.togglePlay(); }
        function next(): void { root.next(); }
        function previous(): void { root.previous(); }
        function stop(): void { root.stop(); }
    }
}
