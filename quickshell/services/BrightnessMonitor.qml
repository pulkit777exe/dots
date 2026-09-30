import QtQuick
import Quickshell
import Quickshell.Io






QtObject {
    id: monitor
    required property ShellScreen modelData
    required property var ddcInfo
    required property bool isDdc
    required property string busNum
    required property bool isAppleDisplay
    required property var getMonitorActive  
    required property var requestOsd        
    required property var syncLevel         

    property real brightness: 0
    property real queuedBrightness: NaN

    readonly property Process initProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(" ");
                const cur = parseInt(parts[parts.length - 2]);
                const max = parseInt(parts[parts.length - 1]);
                if (!isNaN(cur) && !isNaN(max) && max > 0) monitor.brightness = cur / max;
                if (monitor.getMonitorActive() === monitor) monitor.syncLevel(Math.round(monitor.brightness * 100));
            }
        }
    }

    readonly property Timer coalesceTimer: Timer {
        interval: 120
        onTriggered: {
            if (!isNaN(monitor.queuedBrightness)) {
                monitor.setBrightness(monitor.queuedBrightness);
                monitor.queuedBrightness = NaN;
            }
        }
    }

    function setBrightness(value) {
        value = Math.max(0.01, Math.min(1, value));
        const rounded = Math.max(1, Math.round(value * 100));
        if (Math.round(brightness * 100) === rounded) return;
        
        
        if (isDdc && coalesceTimer.running) {
            queuedBrightness = value;
            return;
        }
        
        
        
        if (isDdc) Quickshell.execDetached(["ddcutil", "-b", busNum, "setvcp", "10", rounded]);
        else Quickshell.execDetached(["brightnessctl", "s", `${rounded}%`]);
        queuedBrightness = NaN;
        coalesceTimer.restart();
        
        readbackTimer.restart();
    }

    
    onBrightnessChanged: {
        const rounded = Math.round(brightness * 100);
        if (monitor.getMonitorActive() === monitor) monitor.syncLevel(rounded);
        monitor.requestOsd(rounded);
    }

    readonly property Timer readbackTimer: Timer {
        interval: 120
        onTriggered: {
            if (isDdc) {
                readProc.command = ["bash", "-c", "command -v ddcutil >/dev/null && ddcutil -b " + busNum + " getvcp 10 --brief || true"];
                readProc.running = true;
            } else if (!isAppleDisplay) {
                
                readProc.command = ["sh", "-c", "echo a b c $(brightnessctl g) $(brightnessctl m)"];
                readProc.running = true;
            }
        }
    }
    readonly property Process readProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(" ");
                const cur = parseInt(parts[parts.length-2]);
                const max = parseInt(parts[parts.length-1]);
                if (!isNaN(cur) && !isNaN(max) && max > 0) {
                    const actual = cur / max;
                    if (Math.abs(actual - monitor.brightness) > 0.005) monitor.brightness = actual;
                }
            }
        }
    }

    function initBrightness() {
        if (isDdc) initProc.command = ["ddcutil", "-b", busNum, "getvcp", "10", "--brief"];
        else initProc.command = ["sh", "-c", "echo a b c $(brightnessctl g) $(brightnessctl m)"];
        initProc.running = true;
    }

    onBusNumChanged: initBrightness()
    Component.onCompleted: initBrightness()
}
