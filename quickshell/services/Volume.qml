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

    // ── Device + stream enumeration (Control Centre "Sound" page) ────
    //
    // Per the Quickshell 0.3.1 Pipewire API:
    //   PwNode.isSink  — true when the node ACCEPTS audio from other
    //                    nodes, i.e. an output/sink device.
    //   PwNode.isStream — true when the node is a program rather than
    //                    hardware, i.e. an application stream.
    // So: hardware + isSink = output, hardware + !isSink = input,
    // isStream = an app. That is the three groups the Sound page shows.
    //
    // Filtered once here rather than in the view, so the panel stays a
    // visual leaf and the Pipewire knowledge stays in the service.

    readonly property var _allNodes: Pipewire.nodes

    function _isAudioNode(n) {
        return n !== null && n !== undefined && n.audio !== null;
    }

    // Hardware output devices.
    readonly property var sinks: _filterNodes(n => !n.isStream && n.isSink && _isAudioNode(n))
    // Hardware input devices.
    readonly property var sources: _filterNodes(n => !n.isStream && !n.isSink && _isAudioNode(n))
    // Application streams.
    readonly property var streams: _filterNodes(n => n.isStream && _isAudioNode(n))

    // Pipewire.nodes is an ObjectModel; build a plain array so views can
    // bind to it directly. Recomputed whenever the node list changes.
    function _filterNodes(pred) {
        const out = [];
        const model = _allNodes;
        if (!model || !model.values) return out;
        for (let i = 0; i < model.values.length; i++) {
            const n = model.values[i];
            if (n && pred(n)) out.push(n);
        }
        return out;
    }

    // Nodes must be bound for `.properties` (media.name, application.name)
    // to be valid, so keep every enumerated node tracked.
    PwObjectTracker {
        objects: root._trackedNodes
    }
    readonly property var _trackedNodes: sinks.concat(sources, streams)

    // Human label, preferring the friendlier of nickname/description.
    function displayName(n) {
        if (!n) return "";
        const d = n.description || "";
        const k = n.nickname || "";
        if (d && k) return d;
        return d || k || n.name || "";
    }

    function setDefaultSink(node) {
        if (!node) return;
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node) {
        if (!node) return;
        Pipewire.preferredDefaultAudioSource = node;
    }

    function isDefaultSink(node) {
        return node !== null && node !== undefined && node === Pipewire.defaultAudioSink;
    }

    function isDefaultSource(node) {
        return node !== null && node !== undefined && node === Pipewire.defaultAudioSource;
    }

    // ── IPC ─────────────────────────────────────────────────────────
    IpcHandler {
        target: "audio"
        function getVolume(): int { return root.volumePercent; }
        function setVolume(v: string): void { root.setVolume(parseInt(v)); }
        function toggleMute(): void { root.toggleMute(); }
    }
}
