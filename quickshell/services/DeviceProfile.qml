pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// DeviceProfile — portability + low-spec detection
// Event-driven, no polling. Determines if device is low-spec to reduce
// animations, cava framerate, shadow quality etc.

Singleton {
    id: root
    property bool lowSpec: false
    property bool isLowMem: false
    property bool isLowCpu: false
    property int memKB: 0
    property int cpuCount: 0

    // Expose for MotionConfig to reduce motion on low-spec
    property bool shouldReduceMotion: lowSpec

    Process {
        id: memProbe
        command: ["bash", "-c", "awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                let v = parseInt(text.trim()) || 0
                root.memKB = v
                root.isLowMem = v > 0 && v < 4000000 // <4GB
                root._updateLowSpec()
            }
        }
    }
    Process {
        id: cpuProbe
        command: ["bash", "-c", "nproc 2>/dev/null || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                let v = parseInt(text.trim()) || 0
                root.cpuCount = v
                root.isLowCpu = v > 0 && v <= 2
                root._updateLowSpec()
            }
        }
    }
    function _updateLowSpec() {
        // Low-spec if low mem or low cpu, or manually forced via env
        let forced = Quickshell.env("QUICKSHELL_LOW_SPEC") === "1"
        root.lowSpec = forced || root.isLowMem || root.isLowCpu
        if (root.lowSpec) console.log("DeviceProfile: low-spec mode enabled (mem", root.memKB, "KB, cpu", root.cpuCount, ")")
    }

    Component.onCompleted: {
        memProbe.running = true
        cpuProbe.running = true
        // Also check for manual reduce motion env
        if (Quickshell.env("QUICKSHELL_REDUCE_MOTION") === "1") {
            console.log("DeviceProfile: reduce motion forced via env")
        }
    }
}
