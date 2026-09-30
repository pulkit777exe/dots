pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Io



Singleton {
    id: root

    
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool sinkAvailable: sink !== null
    readonly property bool sourceAvailable: source !== null

    readonly property real volume: sinkAvailable ? sink.audio.volume : 0
    readonly property bool muted: sinkAvailable ? sink.audio.muted : true
    readonly property int volumePercent: Math.round(volume * 100)

    
    
    
    
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

    
    
    
    
    
    
    
    
    
    
    
    

    readonly property var allNodes: Pipewire.nodes

    function isAudioNode(n) {
        return n !== null && n !== undefined && n.audio !== null;
    }

    
    readonly property var sinks: filterNodes(n => !n.isStream && n.isSink && isAudioNode(n))
    
    readonly property var sources: filterNodes(n => !n.isStream && !n.isSink && isAudioNode(n))
    
    readonly property var streams: filterNodes(n => n.isStream && isAudioNode(n))

    
    
    function filterNodes(pred) {
        const out = [];
        const model = allNodes;
        if (!model || !model.values) return out;
        for (let i = 0; i < model.values.length; i++) {
            const n = model.values[i];
            if (n && pred(n)) out.push(n);
        }
        return out;
    }

    
    
    PwObjectTracker {
        objects: root.trackedNodes
    }
    readonly property var trackedNodes: sinks.concat(sources, streams)

    
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

    
    IpcHandler {
        target: "audio"
        function getVolume(): int { return root.volumePercent; }
        function setVolume(v: string): void { root.setVolume(parseInt(v)); }
        function toggleMute(): void { root.toggleMute(); }
    }
}
