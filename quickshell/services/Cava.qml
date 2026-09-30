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
        cavaProc.running = false
        running = false
        levels = [0,0,0]
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
            if (root.running) {
                
                restartTimer.start()
            }
        }
    }
    Timer { id: restartTimer; interval: 1000; onTriggered: { if (root.running) cavaProc.running = true } }

    
    Connections {
        target: Media
        function onHasPlayerChanged() { if (shouldRun()) start(); else stop(); }
        function onPlayingChanged() { if (shouldRun()) start(); else stop(); }
    }
    Connections {
        target: DeviceProfile
        function onLowSpecChanged() {
            if (running) { stop(); start(); } 
        }
    }

    Component.onCompleted: {
        
        Qt.callLater(() => { if (shouldRun()) start(); else stop(); })
    }
}
