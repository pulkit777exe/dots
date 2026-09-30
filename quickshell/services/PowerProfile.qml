pragma Singleton



import QtQuick
import Quickshell
import Quickshell.Io



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
                    monitor.running = true;
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

    Process {
        id: monitor
        command: ["powerprofilesctl", "monitor"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                
                
                const val = line.trim();
                if (root.profiles.includes(val)) {
                    root.active = val;
                    root.profileChanged(val);
                }
            }
        }
        onExited: (code, status) => {
            if (root.usePlatformFallback) {
                
                return;
            }
            restartTimer.start()
        }
    }
    Timer { id: restartTimer; interval: 3000; onTriggered: monitor.running = true }

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
