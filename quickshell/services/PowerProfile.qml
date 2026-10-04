pragma Singleton



import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower as QsUPower



Singleton {
    id: root

    property bool available: false
    property string active: "balanced"          
    property var profiles: ["power-saver", "balanced", "performance"]

    signal profileChanged(string profile)

    function setProfile(profile) {
        if (!available || profile === active) return;
        if (usePlatformFallback) {
            
            const p = toPlatformProfile(profile);
            platformSetter.command = ["bash", "-c", "echo '" + p + "' | pkexec tee /sys/firmware/acpi/platform_profile >/dev/null 2>&1 || echo '" + p + "' | tee /sys/firmware/acpi/platform_profile >/dev/null; echo " + p + "| cat /sys/firmware/acpi/platform_profile | grep -q " + p + " && echo ok || echo fail"];
            platformSetter.running = true;
        } else {
            setter.command = ["powerprofilesctl", "set", profile];
            setter.running = true;
        }
    }

    function cycle() {
        const idx = profiles.indexOf(active);
        if (idx === -1) {
            setProfile(profiles[0]);
            return;
        }
        setProfile(profiles[(idx + 1) % profiles.length]);
    }

    Process { id: setter; onExited: (code) => { if (code !== 0) console.warn("PowerProfile: profile set failed (exit", code, ")") } }
    Process {
        id: platformSetter
        stdout: StdioCollector { id: platformSetterOut }
        stderr: StdioCollector { id: platformSetterErr }
        onExited: (code) => {
            if (code !== 0) console.warn("PowerProfile: platform_profile set failed", platformSetterOut.text, platformSetterErr.text);
            
            platformProbe.running = true;
        }
    }

    
    
    
    function fromPlatformProfile(v) {
        const s = v.trim();
        if (s === "quiet") return "power-saver";
        if (s === "balanced" || s === "performance") return s;
        return s;
    }
    function toPlatformProfile(v) {
        if (v === "power-saver") return "quiet";
        if (v === "balanced" || v === "performance") return v;
        return v;
    }
    property bool usePlatformFallback: false

    Process {
        id: probe
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const val = text.trim();
                if (val.length > 0) {
                    root.available = true;
                    root.usePlatformFallback = false;
                    root.active = val;
                }
            }
        }
        stderr: StdioCollector { id: probeErr }
        onExited: (code) => {
            if (!root.available) {
                
                platformProbe.running = true;
            }
        }
    }
    Process {
        id: platformProbe
        command: ["cat", "/sys/firmware/acpi/platform_profile"]
        stdout: StdioCollector {
            onStreamFinished: {
                const val = text.trim();
                if (val.length > 0) {
                    root.available = true;
                    root.usePlatformFallback = true;
                    root.active = fromPlatformProfile(val);
                    choicesProbe.running = true;
                }
            }
        }
    }
    Process {
        id: choicesProbe
        command: ["cat", "/sys/firmware/acpi/platform_profile_choices"]
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = text.trim();
                if (txt.length > 0) {
                    const raw = txt.split(/\s+/);
                    root.profiles = raw.map(fromPlatformProfile);
                }
            }
        }
    }
    FileView {
        id: platformWatcher
        path: "/sys/firmware/acpi/platform_profile"
        watchChanges: true
        printErrors: false
        onFileChanged: platformProbe.running = true
    }
    Component.onCompleted: probe.running = true

    // The daemon's ActiveProfile is tracked by subscribing to it.
    //
    // It used to be tracked by running `powerprofilesctl monitor`, which is not
    // a subcommand of this tool -- it exits 2 with "invalid choice: 'monitor'".
    // The Process had no stderr collector and the shell's fd 2 is /dev/null, so
    // every rejection was thrown away; onExited then started a 3000ms timer
    // that restarted it. A fork every three seconds, for as long as the shell
    // was up: 19/min measured, ~27360/day, ~95ms of CPU each, and it never said
    // a word about why.
    //
    // Quickshell 0.3.1 already binds that same D-Bus property. QsUPower's
    // PowerProfiles singleton mirrors
    // org.freedesktop.UPower.PowerProfiles.ActiveProfile and emits
    // profileChanged when it changes, so this is event-driven and forks nothing
    // at all -- which is how services/Wifi.qml already tracks NetworkManager,
    // through a process that stays alive instead of one that is respawned.
    //
    // There is no timer here to re-arm and nothing restarts on failure, so there
    // is no loop left for a bad command to feed.
    //
    // QsUPower.PowerProfile.toString() is Qt's default enum-to-string and
    // answers "Balanced", not the "balanced" that powerprofilesctl prints and
    // that `power get` has always returned, so the enum is mapped to the wire
    // name explicitly. The cases are the enum constants themselves rather than
    // 0/1/2.
    function daemonProfileName() {
        switch (QsUPower.PowerProfiles.profile) {
            case QsUPower.PowerProfile.PowerSaver: return "power-saver";
            case QsUPower.PowerProfile.Balanced: return "balanced";
            case QsUPower.PowerProfile.Performance: return "performance";
        }
        return "";
    }

    function adoptDaemonProfile() {
        // While the daemon has not been confirmed reachable, or while the sysfs
        // path is the one in charge, the answer belongs to somebody else. Until
        // `probe` has run, QsUPower's property holds a default enum value that
        // is indistinguishable from a real reading, so adopting it then would
        // flash the wrong profile into the UI and into `power get`.
        if (root.usePlatformFallback || !root.available) return;
        const name = root.daemonProfileName();
        if (name.length === 0 || name === root.active) return;
        root.active = name;
        root.profileChanged(name);
    }

    Connections {
        target: QsUPower.PowerProfiles
        function onProfileChanged() { root.adoptDaemonProfile() }
    }

    IpcHandler {
        target: "powerprofile"
        function get(): string { return root.active; }
        function set(profile: string): void { root.setProfile(profile); }
        function cycle(): void { root.cycle(); }
        function list(): string { return root.profiles.join("\n"); }
        function isAvailable(): bool { return root.available; }
    }
    IpcHandler {
        target: "power"
        function get(): string { return root.active; }
        function cycle(): void { root.cycle(); }
    }
}
