pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower as QsUPower

Singleton {
    id: root

    property bool available: false
    property string active: "balanced"

    function setProfile(profile: string) {
        if (!available || profile === active) return;
        setter.command = ["powerprofilesctl", "set", profile];
        setter.running = true;
        active = profile;
    }

    Process { id: setter; onExited: (code) => { if (code !== 0) console.warn("PowerProfile: set failed", code); } }

    function daemonProfileName() {
        switch (QsUPower.PowerProfiles.profile) {
            case QsUPower.PowerProfile.PowerSaver: return "power-saver";
            case QsUPower.PowerProfile.Balanced: return "balanced";
            case QsUPower.PowerProfile.Performance: return "performance";
        }
        return "";
    }

    Connections {
        target: QsUPower.PowerProfiles
        function onProfileChanged() {
            const name = root.daemonProfileName();
            if (root.available && name && name !== root.active) root.active = name;
        }
    }

    Process {
        id: probe
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim();
                if (v.length > 0) {
                    root.available = true;
                    root.active = v;
                }
            }
        }
    }
    Component.onCompleted: probe.running = true

    IpcHandler {
        target: "powerprofile"
        function get(): string { return root.active; }
        function set(profile: string): void { root.setProfile(profile); }
        function isAvailable(): bool { return root.available; }
    }
}
