pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io



Singleton {
    id: root

    property string defaultPlayer: ""
    property var playerAliases: [
        { from: "brave", to: "Brave" },
        { from: "chromium", to: "Chromium" },
        { from: "firefox", to: "Firefox" },
        { from: "spotify", to: "Spotify" }
    ]

    
    property MprisPlayer active: null
    readonly property bool hasPlayer: active !== null

    
    property string title: active ? (active.trackTitle || "") : ""
    property string artist: active ? (active.trackArtist || "") : ""
    property string album: active ? (active.trackAlbum || "") : ""
    property bool playing: active ? active.isPlaying : false
    property bool canGoNext: active ? active.canGoNext : false
    property bool canGoPrevious: active ? active.canGoPrevious : false
    property bool canTogglePlaying: active ? active.canTogglePlaying : false
    property string artUrl: active ? getArtUrl(active) : ""
    property string identity: active ? getIdentity(active) : ""

    
    property real length: {
        if (!active) return 0;
        if (active.length && active.length > 0) return active.length;
        const metaLen = active.metadata ? active.metadata["mpris:length"] : 0;
        if (metaLen && metaLen > 0) return metaLen / 1000000;
        return 0;
    }

    
    property real position: 0
    property real progress: (length > 0) ? Math.max(0, Math.min(1, position / length)) : 0

    
    Timer {
        id: positionTicker
        interval: 500
        repeat: true
        running: root.playing && root.hasPlayer
        onTriggered: {
            if (root.active) {
                
                const nativePos = root.active.position;
                if (!isNaN(nativePos) && nativePos > 0 && Math.abs(nativePos - root.position) > 2) {
                    root.position = nativePos;
                } else {
                    
                    if (root.length > 0 && root.position < root.length) {
                        root.position = Math.min(root.length, root.position + 0.5);
                    } else if (root.length === 0) {
                        root.position += 0.5;
                    }
                }
            }
        }
    }

    
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

    
    function togglePlay() {
        if (active && active.canTogglePlaying) {
            active.togglePlaying();
        } else {
            Quickshell.execDetached(["playerctl", "play-pause"]);
        }
        root.playing = !root.playing;
    }

    function next() {
        if (active && active.canGoNext) active.next();
        else Quickshell.execDetached(["playerctl", "next"]);
        refreshState();
    }

    function previous() {
        if (active && active.canGoPrevious) active.previous();
        else Quickshell.execDetached(["playerctl", "previous"]);
        refreshState();
    }

    function stop() {
        if (active) active.stop();
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
        if (active && active.canSeek) {
            active.position = sec;
        }
        Quickshell.execDetached(["playerctl", "position", String(sec)]);
    }

    function refreshState() {
        pickBest();
        posProc.running = true;
    }

    
    function pickBest() {
        const players = Mpris.players.values;
        if (!players || players.length === 0) {
            active = null;
            return;
        }
        
        for (let i = 0; i < players.length; i++) {
            if (players[i].isPlaying) {
                active = players[i];
                syncTrack();
                return;
            }
        }
        
        if (defaultPlayer && defaultPlayer.length > 0) {
            const pref = players.find(p => getIdentity(p) === defaultPlayer);
            if (pref) {
                active = pref;
                syncTrack();
                return;
            }
        }
        
        active = players[players.length - 1];
        syncTrack();
    }

    function syncTrack() {
        if (active) {
            root.title = active.trackTitle || "";
            root.artist = active.trackArtist || "";
            root.album = active.trackAlbum || "";
            root.playing = active.isPlaying;
            root.canGoNext = active.canGoNext;
            root.canGoPrevious = active.canGoPrevious;
            root.canTogglePlaying = active.canTogglePlaying;
            root.artUrl = getArtUrl(active);
            root.identity = getIdentity(active);
            posProc.running = true;
        }
    }

    Connections {
        target: Mpris.players
        function onObjectInsertedPost() { root.pickBest(); }
        function onObjectRemovedPost() { root.pickBest(); }
    }

    Connections {
        target: root.active
        function onIsPlayingChanged() {
            if (root.active) root.playing = root.active.isPlaying;
            root.pickBest();
        }
        function onPostTrackChanged() { root.syncTrack(); }
        function onTrackTitleChanged() { root.syncTrack(); }
        function onTrackArtistChanged() { root.syncTrack(); }
        function onPositionChanged() {
            if (root.active && !isNaN(root.active.position)) {
                root.position = root.active.position;
            }
        }
    }

    Component.onCompleted: {
        pickBest();
        posProc.running = true;
    }

    
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
