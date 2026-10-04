pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io






Singleton {
    id: root
    property var levels: [0, 0, 0] 
    property bool available: false
    property bool running: false

    readonly property string configPath: "/tmp/quickshell-cava.conf"
    property int bars: 3
    
    readonly property int framerate: DeviceProfile.lowSpec ? 15 : 30

    function shouldRun(): bool {
        try {
            
            
            return Media.hasPlayer && Media.playing
        } catch(e) { return false }
    }

    function start() {
        if (running) return
        if (!shouldRun()) return
        
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
        
        configWriter.command = ["bash", "-c", `cat > ${configPath} <<'EOF'
${cfg}
EOF
cat ${configPath}`]
        configWriter.running = true
    }

    function stop() {
        running = false
        levels = [0,0,0]
        // The smoothed copy has to go too, or the next start resumes from the
        // last bar heights instead of from silence.
        smoothedLevels = [0,0,0]
    }

    Process {
        id: configWriter
        stdout: StdioCollector {
            onStreamFinished: {
                
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

        // A binding, not an assignment. It used to be set imperatively, and
        // onExited re-armed it from a 1000ms timer whenever `running` was true:
        // 86400 forks/day if cava ever exited, three times the powerprofilesctl
        // loop this repo shipped, and invisible because there is no cava binary
        // and no media player on this machine to trigger it.
        //
        // Nothing writes cavaProc.running now. `running` is the only thing that
        // starts cava, it is cleared the moment cava exits, and it is set again
        // only by start() -- which is reached from Media, not from cava's own
        // exit. A failure cannot re-arm itself, so there is no interval, no
        // backoff, and no non-zero-exit retry to get wrong.
        running: root.running
        command: ["cava", "-p", root.configPath]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (!line || line.length === 0) return
                const parts = line.split(";").filter(p => p.length>0).map(v => parseInt(v) || 0)
                if (parts.length < root.bars) return
                
                let newLevels = []
                for (let i=0; i<root.bars; i++) {
                    let raw = Math.max(0, Math.min(100, parts[i])) / 100
                    if (raw < 0.05) raw = 0
                    let prev = root.smoothedLevels[i] ?? 0
                    
                    let smoothed = prev * 0.80 + raw * 0.20
                    if (raw > prev) smoothed = prev * 0.70 + raw * 0.30
                    
                    if (Math.abs(smoothed - prev) < 0.03) smoothed = prev
                    
                    smoothed = Math.max(0, Math.min(1, smoothed))
                    newLevels.push(smoothed)
                }
                root.smoothedLevels = newLevels
                root.levels = newLevels.map(v => Math.pow(v, 0.92))
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                
            }
        }
        onExited: (code) => {
            // Cleared first, so the `running` binding above drops and the
            // process cannot be restarted from inside this handler. Restarting
            // is not attempted on either exit code: cava exiting is either
            // deliberate or a failure to fix, and a timer that re-runs it is the
            // fork loop this file used to contain.
            root.running = false
            root.smoothedLevels = [0,0,0]
            root.levels = [0,0,0]
            if (code !== 0) {
                console.warn("Cava: exited with", code, "- not restarting; cava resumes when media starts")
            }
        }
    }

    
    Connections {
        target: Media
        function onHasPlayerChanged() { if (shouldRun()) start(); else stop(); }
        function onPlayingChanged() { if (shouldRun()) start(); else stop(); }
    }
    Connections {
        target: DeviceProfile
        // Unconditional, so a cava that exited is recovered by a lowSpec flip
        // too. start() still decides: it returns early unless media is playing,
        // and stop() has just cleared `running`.
        function onLowSpecChanged() {
            stop(); start()
        }
    }

    Component.onCompleted: {
        
        Qt.callLater(() => { if (shouldRun()) start(); else stop(); })
    }
}
