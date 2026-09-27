import QtQuick
import Quickshell
import Quickshell.Io

// BrightnessMonitor — per-screen monitor helper for Brightness service.
// Extracted from Singleton inline `component Monitor` (v0.3.0: keep delegation
// explicit, avoid Process-as-property cleverness inside Singleton).
// Used via Variants { model: Quickshell.screens; BrightnessMonitor {} }

QtObject {
    id: monitor
    required property ShellScreen modelData
    required property var ddcInfo
    required property bool isDdc
    required property string busNum
    required property bool isAppleDisplay
    required property var getMonitorActive  // () => var
    required property var requestOsd        // (int) => void
    required property var syncLevel         // (int) => void

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
        // Event-driven: don't update brightness/Osd optimistically, let hardware event drive it
        // For DDC, coalesce hardware calls but don't update UI until readback
        if (isDdc && coalesceTimer.running) {
            queuedBrightness = value;
            return;
        }
        // For non-DDC, still event-driven: trigger hardware, UI will update via inotify/readback
        // But for immediate feedback like volume (PipeWire), we also trigger OSD via brightness change
        // So we still need to call hardware
        if (isDdc) Quickshell.execDetached(["ddcutil", "-b", busNum, "setvcp", "10", rounded]);
        else Quickshell.execDetached(["brightnessctl", "s", `${rounded}%`]);
        queuedBrightness = NaN;
        coalesceTimer.restart();
        // Schedule readback for event-driven update (both DDC and brightnessctl)
        readbackTimer.restart();
    }

    // Event-driven OSD: when brightness actually changes via hardware readback, show OSD
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
                // For brightnessctl, read back via sysfs for event-driven update
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
