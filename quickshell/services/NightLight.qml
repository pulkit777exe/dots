pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property bool enabled: false
    property int temperature: 4000
    property bool restored: false

    function restoreFromConfig() {
        enabled = Config.nightLightEnabled;
        temperature = Config.nightLightTemperature;
        restored = true;
        if (available && enabled) apply();
    }

    function toggle() { setEnabled(!enabled); }

    function save() {
        Config.set("nightLightEnabled", enabled);
        Config.set("nightLightTemperature", temperature);
    }

    function apply() {
        if (!available) return;
        setter.command = enabled
            ? ["hyprctl", "hyprsunset", "temperature", String(temperature)]
            : ["hyprctl", "hyprsunset", "identity"];
        setter.running = true;
    }

    function setEnabled(value: bool) {
        enabled = value;
        save();
        if (available) apply();
    }

    function setTemperature(k: int) {
        temperature = Math.max(1000, Math.min(6500, Math.round(k)));
        save();
        if (available && enabled) apply();
    }

    onAvailableChanged: if (available && restored && enabled) apply()

    Connections {
        target: Config
        function onLoadedChanged() { if (Config.loaded) root.restoreFromConfig(); }
    }

    Process { id: setter; onExited: (code) => { if (code !== 0) console.warn("NightLight: failed, exit", code); } }

    Process {
        id: probe
        command: ["bash", "-c", "command -v hyprsunset >/dev/null && echo yes || echo no"]
        stdout: SplitParser {
            onRead: (line) => { if (line.trim() === "yes") root.available = true; }
        }
    }
    Component.onCompleted: {
        probe.running = true;
        if (Config.loaded) restoreFromConfig();
    }

    IpcHandler {
        target: "nightlight"
        function isEnabled(): bool { return root.enabled; }
        function toggle(): void { root.toggle(); }
        function setTemp(k: string): void { root.setTemperature(parseInt(k)); }
    }
}
