pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower as QsUPower

// Power profiles: write through powerprofilesctl, read the daemon's own
// ActiveProfile through Quickshell's UPower binding, which is event-driven
// and forks nothing. (There used to be a `powerprofilesctl monitor` loop
// here -- a subcommand that does not exist, respawned every 3s forever.)

Singleton {
    id: root

    property bool available: false
    property string active: "balanced"
    readonly property var profiles: ["power-saver", "balanced", "performance"]

    function setProfile(profile: string) {
        if (!available || profile === active) return;
        setter.command = ["powerprofilesctl", "set", profile];
        setter.running = true;
        active = profile;   // optimistic; the daemon signal confirms
    }

    Process { id: setter; onExited: (code) => { if (code !== 0) console.warn("PowerProfile: set failed", code); } }

    // The daemon answers as an enum; map it to the wire name explicitly,
    // because Qt's default enum-to-string says "Balanced".
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
