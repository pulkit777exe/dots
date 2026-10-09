pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property bool enabled: false
    property int temperature: 4000

    function toggle() { setEnabled(!enabled); }

    function setEnabled(value: bool) {
        if (!available) return;
        enabled = value;
        setter.command = value
            ? ["hyprctl", "hyprsunset", "temperature", String(temperature)]
            : ["hyprctl", "hyprsunset", "identity"];
        setter.running = true;
    }

    function setTemperature(k: int) {
        temperature = k;
        if (available && enabled) {
            setter.command = ["hyprctl", "hyprsunset", "temperature", String(k)];
            setter.running = true;
        }
    }

    Process { id: setter; onExited: (code) => { if (code !== 0) console.warn("NightLight: failed, exit", code); } }

    Process {
        id: probe
        command: ["bash", "-c", "command -v hyprsunset >/dev/null && echo yes || echo no"]
        stdout: SplitParser {
            onRead: (line) => { if (line.trim() === "yes") root.available = true; }
        }
    }
    Component.onCompleted: probe.running = true

    IpcHandler {
        target: "nightlight"
        function isEnabled(): bool { return root.enabled; }
        function toggle(): void { root.toggle(); }
        function setTemp(k: string): void { root.setTemperature(parseInt(k)); }
    }
}
