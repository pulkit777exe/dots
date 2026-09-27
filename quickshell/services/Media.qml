pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io

/*
  Media service — real-time MPRIS player integration.
  - Live track metadata (title, artist, album, artUrl)
  - Real-time position tracking and smooth progress ticker (500ms intervals)
  - Interactive seeking (seek, seekSeconds)
  - Play, pause, togglePlay, next, previous, stop
  - Multi-player priority (currently playing wins, fallback to last active)
*/

Singleton {
    id: root

    property string defaultPlayer: ""
    property var playerAliases: [
        { from: "brave", to: "Brave" },
        { from: "chromium", to: "Chromium" },
        { from: "firefox", to: "Firefox" },
        { from: "spotify", to: "Spotify" }
    ]

    // ── Active Player ───────────────────────────────────────────────
    property MprisPlayer _active: null
    readonly property MprisPlayer active: _active
    readonly property bool hasPlayer: _active !== null

    // ── Metadata Properties ─────────────────────────────────────────
    property string title: _active ? (_active.trackTitle || "") : ""
    property string artist: _active ? (_active.trackArtist || "") : ""
    property string album: _active ? (_active.trackAlbum || "") : ""
    property bool playing: _active ? _active.isPlaying : false
    property bool canGoNext: _active ? _active.canGoNext : false
    property bool canGoPrevious: _active ? _active.canGoPrevious : false
    property bool canTogglePlaying: _active ? _active.canTogglePlaying : false
    property string artUrl: _active ? getArtUrl(_active) : ""
    property string identity: _active ? getIdentity(_active) : ""

    // Length in seconds
    property real length: {
        if (!_active) return 0;
        if (_active.length && _active.length > 0) return _active.length;
        const metaLen = _active.metadata ? _active.metadata["mpris:length"] : 0;
        if (metaLen && metaLen > 0) return metaLen / 1000000;
        return 0;
    }

    // Position in seconds (locally ticked in real-time)
    property real position: 0
    property real progress: (length > 0) ? Math.max(0, Math.min(1, position / length)) : 0

    // ── Real-Time Position Ticker ───────────────────────────────────
    Timer {
        id: positionTicker
        interval: 500
        repeat: true
        running: root.playing && root.hasPlayer
        onTriggered: {
            if (root._active) {
                // If Quickshell native position is valid and updating, use it
                const nativePos = root._active.position;
                if (!isNaN(nativePos) && nativePos > 0 && Math.abs(nativePos - root.position) > 2) {
                    root.position = nativePos;
                } else {
                    // Smooth local increment
                    if (root.length > 0 && root.position < root.length) {
                        root.position = Math.min(root.length, root.position + 0.5);
                    } else if (root.length === 0) {
                        root.position += 0.5;
                    }
                }
            }
        }
    }

    // Sync position with playerctl periodically to ensure 0 drift
    Timer {
        id: syncTimer
        interval: 2500
        repeat: true
        running: root.playing && root.hasPlayer
        onTriggered: posProc.running = true
    }

    Process {
        id: posProc
        command: ["playerctl", "position"]
        stdout: StdioCollector {
            id: posCollector
            onStreamFinished: {
                const val = parseFloat((posCollector.text || "").trim());
                if (!isNaN(val) && val >= 0) {
                    root.position = val;
                }
            }
        }
    }

    function formatTime(seconds) {
        if (!seconds || seconds <= 0 || isNaN(seconds)) return "0:00";
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // ── Helpers ─────────────────────────────────────────────────────
    function getIdentity(player) {
        if (!player) return "";
        const id = player.identity || "";
        const lower = id.toLowerCase();
        for (let i = 0; i < playerAliases.length; i++) {
            if (lower.includes(playerAliases[i].from)) return playerAliases[i].to;
        }
        return id;
    }

    function getArtUrl(player) {
        if (!player) return "";
        if (player.trackArtUrl && player.trackArtUrl.length > 0) return player.trackArtUrl;
        const meta = player.metadata || {};
        if (meta["mpris:artUrl"]) return meta["mpris:artUrl"];
        const url = meta["xesam:url"] || "";
        if (url.startsWith("https://www.youtube.com/watch")) {
            const match = url.match(/[?&]v=([\w-]{11})/);
            if (match && match[1]) return "https://img.youtube.com/vi/" + match[1] + "/hqdefault.jpg";
        }
        return "";
    }

    // ── Public Controls ─────────────────────────────────────────────
    function togglePlay() {
        if (_active && _active.canTogglePlaying) {
            _active.togglePlaying();
        } else {
            Quickshell.execDetached(["playerctl", "play-pause"]);
        }
        root.playing = !root.playing;
    }

    function next() {
        if (_active && _active.canGoNext) _active.next();
        else Quickshell.execDetached(["playerctl", "next"]);
        refreshState();
    }

    function previous() {
        if (_active && _active.canGoPrevious) _active.previous();
        else Quickshell.execDetached(["playerctl", "previous"]);
        refreshState();
    }

    function stop() {
        if (_active) _active.stop();
        else Quickshell.execDetached(["playerctl", "stop"]);
        root.playing = false;
    }

    function seek(fraction) {
        const clamped = Math.max(0, Math.min(1, fraction));
        if (root.length > 0) {
            const targetSec = clamped * root.length;
            seekSeconds(targetSec);
        }
    }

    function seekSeconds(sec) {
        root.position = sec;
        if (_active && _active.canSeek) {
            _active.position = sec;
        }
        Quickshell.execDetached(["playerctl", "position", String(sec)]);
    }

    function refreshState() {
        _pickBest();
        posProc.running = true;
    }

    // ── Player Selection ────────────────────────────────────────────
    function _pickBest() {
        const players = Mpris.players.values;
        if (!players || players.length === 0) {
            _active = null;
            return;
        }
        // First priority: player that is currently playing
        for (let i = 0; i < players.length; i++) {
            if (players[i].isPlaying) {
                _active = players[i];
                _syncTrack();
                return;
            }
        }
        // Second priority: default player name match
        if (defaultPlayer && defaultPlayer.length > 0) {
            const pref = players.find(p => getIdentity(p) === defaultPlayer);
            if (pref) {
                _active = pref;
                _syncTrack();
                return;
            }
        }
        // Fallback: most recently added player
        _active = players[players.length - 1];
        _syncTrack();
    }

    function _syncTrack() {
        if (_active) {
            root.title = _active.trackTitle || "";
            root.artist = _active.trackArtist || "";
            root.album = _active.trackAlbum || "";
            root.playing = _active.isPlaying;
            root.canGoNext = _active.canGoNext;
            root.canGoPrevious = _active.canGoPrevious;
            root.canTogglePlaying = _active.canTogglePlaying;
            root.artUrl = getArtUrl(_active);
            root.identity = getIdentity(_active);
            posProc.running = true;
        }
    }

    Connections {
        target: Mpris.players
        function onObjectInsertedPost() { root._pickBest(); }
        function onObjectRemovedPost() { root._pickBest(); }
    }

    Connections {
        target: root._active
        function onIsPlayingChanged() {
            if (root._active) root.playing = root._active.isPlaying;
            root._pickBest();
        }
        function onPostTrackChanged() { root._syncTrack(); }
        function onTrackTitleChanged() { root._syncTrack(); }
        function onTrackArtistChanged() { root._syncTrack(); }
        function onPositionChanged() {
            if (root._active && !isNaN(root._active.position)) {
                root.position = root._active.position;
            }
        }
    }

    Component.onCompleted: {
        _pickBest();
        posProc.running = true;
    }

    // ── IPC Compatibility ───────────────────────────────────────────
    IpcHandler {
        target: "mpris"
        function play() { root.togglePlay(); }
        function pause() { root.togglePlay(); }
        function playPause() { root.togglePlay(); }
        function previous() { root.previous(); }
        function next() { root.next(); }
        function stop() { root.stop(); }
        function toggle() { root.togglePlay(); }
    }
}
