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

    PwObjectTracker { objects: [root.sink, root.source] }

    readonly property real volume: sinkAvailable ? sink.audio.volume : 0
    readonly property bool muted: sinkAvailable ? sink.audio.muted : true
    readonly property int volumePercent: Math.round(volume * 100)

    readonly property real micVolume: sourceAvailable ? source.audio.volume : 0
    readonly property bool micMuted: sourceAvailable ? source.audio.muted : true
    readonly property int micVolumePercent: Math.round(micVolume * 100)

    readonly property string iconName: {
        if (!sinkAvailable || muted || volumePercent === 0) return "volume_off";
        if (volumePercent >= 50) return "volume_up";
        return "volume_down";
    }

    function setVolume(pct: real) {
        if (!sinkAvailable) return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, pct / 100));
    }

    function toggleMute() {
        if (sinkAvailable) sink.audio.muted = !sink.audio.muted;
    }

    function setMicVolume(pct: real) {
        if (!sourceAvailable) return;
        source.audio.muted = false;
        source.audio.volume = Math.max(0, Math.min(1, pct / 100));
    }

    function filterNodes(pred) {
        const out = [];
        const model = Pipewire.nodes;
        if (!model || !model.values) return out;
        for (const n of model.values) {
            if (n && n.audio !== null && pred(n)) out.push(n);
        }
        return out;
    }

    readonly property var sinks: filterNodes(n => !n.isStream && n.isSink)
    readonly property var sources: filterNodes(n => !n.isStream && !n.isSink)
    readonly property var streams: filterNodes(n => n.isStream)

    PwObjectTracker { objects: root.sinks.concat(root.sources, root.streams) }

    function displayName(n) {
        if (!n) return "";
        return n.description || n.nickname || n.name || "";
    }

    function isDefaultSink(n) { return n !== null && n !== undefined && n === Pipewire.defaultAudioSink; }
    function isDefaultSource(n) { return n !== null && n !== undefined && n === Pipewire.defaultAudioSource; }
    function setDefaultSink(n) { if (n) Pipewire.preferredDefaultAudioSink = n; }
    function setDefaultSource(n) { if (n) Pipewire.preferredDefaultAudioSource = n; }

    IpcHandler {
        target: "audio"
        function getVolume(): int { return root.volumePercent; }
        function setVolume(v: string): void { root.setVolume(parseInt(v)); }
        function toggleMute(): void { root.toggleMute(); }
    }
}
