pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Io

/*
  Volume service — thin adapter over Quickshell.Services.Pipewire.

  Consumer API:
    volume, volumePercent, muted, setVolume(pct), toggleMute()
    micVolume, micVolumePercent, micMuted, setMicVolume(pct)
    sinkAvailable, sink, sourceAvailable, source
    iconName, osdRequested(percent)

  Pipewire owns all state. This service only normalizes it.
*/

Singleton {
    id: root

    // ── Core properties ─────────────────────────────────────────────
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool sinkAvailable: sink !== null
    readonly property bool sourceAvailable: source !== null

    readonly property real volume: sinkAvailable ? sink.audio.volume : 0
    readonly property bool muted: sinkAvailable ? sink.audio.muted : true
    readonly property int volumePercent: Math.round(volume * 100)

    // PwObjectTracker binds the sink/source nodes — without it Pipewire
    // reports them as "unbound" and audio.volume/muted read invalid (0).
    // This is why volume keys/OSD silently did nothing: external wpctl
    // changes came in, but Quickshell never saw them.
    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    readonly property real micVolume: sourceAvailable ? source.audio.volume : 0
    readonly property bool micMuted: sourceAvailable ? source.audio.muted : true
    readonly property int micVolumePercent: Math.round(micVolume * 100)

    readonly property string iconName: {
        if (!sinkAvailable || muted) return "volume_mute";
        if (volumePercent >= 66) return "volume_up";
        if (volumePercent >= 33) return "volume_down";
        if (volumePercent > 0) return "volume_down";
        return "volume_off";
    }

    signal osdRequested(int percent)
    onVolumePercentChanged: osdRequested(volumePercent)
    onMutedChanged: osdRequested(volumePercent)

    // ── Controls ────────────────────────────────────────────────────
    function setVolume(pct: real): void {
        if (!sinkAvailable) return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, pct / 100.0));
    }

    function toggleMute(): void {
        if (!sinkAvailable) return;
        sink.audio.muted = !sink.audio.muted;
    }

    function setMicVolume(pct: real): void {
        if (!sourceAvailable) return;
        source.audio.muted = false;
        source.audio.volume = Math.max(0, Math.min(1, pct / 100.0));
    }

    // ── IPC ─────────────────────────────────────────────────────────
    IpcHandler {
        target: "audio"
        function getVolume(): int { return root.volumePercent; }
        function setVolume(v: string): void { root.setVolume(parseInt(v)); }
        function toggleMute(): void { root.toggleMute(); }
    }
}
