pragma Singleton



import QtQuick
import Quickshell
import Quickshell.Io



Singleton {
    id: root

    property bool available: false
    property bool enabled: false
    property int nightTemperature: 4000

    signal toggled(bool enabled)

    function toggle() {
        setEnabled(!enabled)
    }

    function setEnabled(value) {
        if (!available) return
        enabled = value
        if (value) {
            setter.command = ["hyprctl", "hyprsunset", "temperature", String(nightTemperature)]
        } else {
            setter.command = ["hyprctl", "hyprsunset", "identity"]
        }
        setter.running = true
        toggled(enabled)
    }

    function setTemperature(kelvin) {
        nightTemperature = kelvin
        if (available && enabled) {
            setter.command = ["hyprctl", "hyprsunset", "temperature", String(kelvin)]
            setter.running = true
        }
    }

    Process { id: setter; onExited: (code) => { if (code !== 0) console.warn("NightLight: redshift set failed (exit", code, ")") } }

    
    Process {
        id: probe
        command: ["bash", "-c", "command -v hyprsunset >/dev/null && echo yes || echo no"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => { if (line.trim() === "yes") root.available = true }
        }
    }
    Component.onCompleted: probe.running = true

    IpcHandler {
        target: "nightlight"
        function isEnabled(): bool { return root.enabled; }
        function toggle(): void { root.toggle(); }
        function enable(): void { root.setEnabled(true); }
        function disable(): void { root.setEnabled(false); }
        function setTemp(k: string): void { root.setTemperature(parseInt(k)); }
    }

}
