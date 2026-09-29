pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Cava — audio visualizer for Island hover (like Image 1 "L..I" bars)
// Uses `cava` with raw ascii output. Provides `levels` 0-1 for 3 bars.
// Falls back to silent if cava not installed or no audio.

Singleton {
    id: root
    property var levels: [0, 0, 0] // 3 bars
    property bool available: false
    property bool running: false

    readonly property string configPath: "/tmp/quickshell-cava.conf"
    property int bars: 3
    // Low-spec: halve framerate, reduce smoothing cost
    readonly property int framerate: DeviceProfile.lowSpec ? 15 : 30

    function shouldRun(): bool {
        try {
            // Only run when media playing and island needs it (pill other-workspace or expanded)
            // For portability, check Media availability
            return Media.hasPlayer && Media.playing
        } catch(e) { return false }
    }

    function start() {
        if (running) return
        if (!shouldRun()) return
        // Write cava config — event-driven, not polling
        let cfg = `
[general]
framerate = ${framerate}
bars = ${bars}
bar_width = 1
bar_spacing = 1
[output]
method = raw
channels = mono
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
bit_format = 8bit
[smoothing]
noise_reduction = ${DeviceProfile.lowSpec ? 50 : 35}
monstercat = ${DeviceProfile.lowSpec ? 0.8 : 1.2}
waves = 0
integral = 77
gravity = 100
`
        // Use bash to write config then run cava
        configWriter.command = ["bash", "-c", `cat > ${configPath} <<'EOF'
${cfg}
EOF
cat ${configPath}`]
        configWriter.running = true
    }

    function stop() {
        cavaProc.running = false
        running = false
        levels = [0,0,0]
    }

    Process {
        id: configWriter
        stdout: StdioCollector {
            onStreamFinished: {
                // Config written, now probe cava
                probe.command = ["bash", "-c", "command -v cava >/dev/null && echo yes || echo no"]
                probe.running = true
            }
        }
    }
    Process {
        id: probe
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (line.trim() === "yes") {
                    root.available = true
                    cavaProc.running = true
                    root.running = true
                } else {
                    root.available = false
                }
            }
        }
    }

    property var smoothedLevels: [0,0,0]

    Process {
        id: cavaProc
        // cava will output lines like "10;40;70;" per frame
        command: ["cava", "-p", root.configPath]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (!line || line.length === 0) return
                const parts = line.split(";").filter(p => p.length>0).map(v => parseInt(v) || 0)
                if (parts.length < root.bars) return
                // Very smooth: heavy smoothing, dead zone, no jitter
                let newLevels = []
                for (let i=0; i<root.bars; i++) {
                    let raw = Math.max(0, Math.min(100, parts[i])) / 100
                    if (raw < 0.05) raw = 0
                    let prev = root.smoothedLevels[i] ?? 0
                    // Heavy smoothing: 0.80/0.20, slower attack
                    let smoothed = prev * 0.80 + raw * 0.20
                    if (raw > prev) smoothed = prev * 0.70 + raw * 0.30
                    // Dead zone: ignore tiny changes <0.03 to avoid micro-vibration
                    if (Math.abs(smoothed - prev) < 0.03) smoothed = prev
                    // Clamp
                    smoothed = Math.max(0, Math.min(1, smoothed))
                    newLevels.push(smoothed)
                }
                root.smoothedLevels = newLevels
                root.levels = newLevels.map(v => Math.pow(v, 0.92))
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                // cava prints errors to stderr, ignore if not running
            }
        }
        onExited: (code) => {
            if (root.running) {
                // Restart after 1s if exited unexpectedly
                restartTimer.start()
            }
        }
    }
    Timer { id: restartTimer; interval: 1000; onTriggered: { if (root.running) cavaProc.running = true } }

    // Event-driven start/stop for portability + low-spec (no polling when idle)
    Connections {
        target: Media
        function onHasPlayerChanged() { if (shouldRun()) start(); else stop(); }
        function onPlayingChanged() { if (shouldRun()) start(); else stop(); }
    }
    Connections {
        target: DeviceProfile
        function onLowSpecChanged() {
            if (running) { stop(); start(); } // regenerate config with new framerate
        }
    }

    Component.onCompleted: {
        // Defer start until Media and DeviceProfile probed
        Qt.callLater(() => { if (shouldRun()) start(); else stop(); })
    }
}
