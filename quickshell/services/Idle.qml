pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen-idle timers. Timeout values live in Config; this module owns the
// only write path to hypridle.conf (via the generator) and the daemon
// restart that picks it up. Slider gestures debounce into one
// regenerate+restart. Plug/unplug re-applies automatically when the
// separate-charging profile is enabled.
Singleton {
    id: root

    readonly property bool available: hasHypridle
    property bool hasHypridle: false

    Process {
        id: probe
        command: ["bash", "-c", "command -v hypridle >/dev/null && echo -n y || echo -n n"]
        stdout: StdioCollector {
            onStreamFinished: { root.hasHypridle = (text || "").trim() === "y"; }
        }
    }

    Process {
        id: generator
        onExited: (code) => {
            if (code === 0) {
                restarter.command = ["bash", "-c",
                    "pkill -x hypridle 2>/dev/null; systemctl --user restart hypridle.service"];
                restarter.running = true;
            } else {
                console.warn("Idle: conf generator failed", code);
            }
        }
    }

    Process {
        id: restarter
        onExited: (code) => { if (code !== 0) console.warn("Idle: hypridle restart failed", code); }
    }

    Timer {
        id: debounce
        interval: 800
        onTriggered: {
            if (generator.running || restarter.running) { debounce.restart(); return; }
            generator.command = ["python3", Quickshell.shellDir + "/scripts/generate-hypridle-conf.py"];
            generator.running = true;
        }
    }

    function apply() {
        if (!root.available) return;
        debounce.restart();
    }

    function formatTimeout(s: int): string {
        if (s <= 0) return "Off";
        if (s < 120) return s + " s";
        const m = Math.round(s / 60);
        return m + " min";
    }

    Connections {
        target: Battery
        function onChargingChanged() {
            if (Config.idleSeparateCharging) root.apply();
        }
    }

    Component.onCompleted: probe.running = true
}
