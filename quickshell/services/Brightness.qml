pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen brightness: the laptop backlight (brightnessctl + an inotify
// watcher for changes made outside the shell) and, for the Display page,
// per-monitor brightness via scripts/monitors.py.
//
// Clamp floor is 1, not 0: setting the backlight to 0 either fails or
// leaves you tapping in the dark.

Singleton {
    id: root

    property bool available: false
    property string device: ""
    property int max: 1
    property int level: 0            // 0..100

    // ---- discovery ---------------------------------------------------------
    Process {
        id: listProc
        command: ["brightnessctl", "-m", "-l"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const p = line.split(",");
                    if (p.length >= 4 && p[1] === "backlight") {
                        root.device = p[0];
                        root.available = true;
                        readProc.running = true;
                        watcher.command = [Quickshell.shellDir + "/scripts/inotify-watch.py",
                            "/sys/class/backlight/" + root.device + "/brightness"];
                        watcher.running = true;
                        return;
                    }
                }
            }
        }
    }

    function read() { if (available) readProc.running = true; }

    Process {
        id: readProc
        command: ["brightnessctl", "-d", root.device, "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(",");
                if (p.length >= 4) {
                    const cur = parseInt(p[2]);
                    const mx = parseInt(p[3]);
                    if (!isNaN(cur) && !isNaN(mx) && mx > 0) {
                        root.max = mx;
                        root.level = Math.round(cur / mx * 100);
                    }
                }
            }
        }
    }

    // External changes (fn keys, other tools) arrive as one path line each.
    Process {
        id: watcher
        stdout: SplitParser { onRead: root.read() }
        onExited: if (root.available) retry.restart()
    }
    Timer { id: retry; interval: 3000; onTriggered: watcher.running = true }

    Component.onCompleted: listProc.running = true

    // ---- write ---------------------------------------------------------------

    function setBrightness(pct: int) {
        if (!available) return;
        const v = Math.max(1, Math.min(100, Math.round(pct)));
        writeProc.command = ["brightnessctl", "-d", root.device, "set", String(Number(v.toFixed(6))) + "%"];
        writeProc.running = true;
        level = v;   // optimistic; the watcher corrects if the write was refused
    }

    Process {
        id: writeProc
        onExited: root.read()
    }

    function step(delta: int) { setBrightness(level + delta); }

    // ---- per-monitor (Display page) -------------------------------------------

    property var monitorList: []        // [{name,width,height,hz,scale,focused,modes,brightness}]
    property var pendingBrightness: ({})  // name -> 0..100, optimistic values

    function refreshMonitors() {
        infoProc.running = true;
    }

    Process {
        id: infoProc
        command: ["python3", Quickshell.shellDir + "/scripts/monitors.py", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitorList = JSON.parse(text);
                } catch (e) {
                    console.warn("Brightness: bad monitors.py output:", e);
                }
            }
        }
        onExited: if (code !== 0) console.warn("Brightness: monitors.py info failed", code)
    }

    function monitorBrightness(name: string): real {
        if (pendingBrightness[name] !== undefined) return pendingBrightness[name];
        for (const m of monitorList) {
            if (m.name !== name) continue;
            if (m.brightness !== null && m.brightness !== undefined) return m.brightness;
            // No ddcutil for the internal panel: the backlight reading is it.
            if (name.startsWith("eDP")) return level;
        }
        return 0;
    }

    // A drag fires faster than ddcutil answers, so the value is queued and a
    // 150ms-debounced launcher sends only the latest one.
    property var pendingSet: ({})   // name -> 0..100

    function setMonitorBrightness(name: string, pct: int) {
        const v = Math.max(1, Math.min(100, Math.round(pct)));
        const pending = Object.assign({}, pendingBrightness);
        pending[name] = v;
        pendingBrightness = pending;
        const queue = Object.assign({}, pendingSet);
        queue[name] = v;
        pendingSet = queue;
        setDebounce.restart();
    }

    Timer {
        id: setDebounce
        interval: 150
        onTriggered: {
            const names = Object.keys(root.pendingSet);
            if (names.length === 0) return;
            const name = names[names.length - 1];
            root.pendingSet = {};
            setProc.command = ["python3", Quickshell.shellDir + "/scripts/monitors.py", "set", name, String(root.pendingBrightness[name])];
            setProc.running = true;
        }
    }

    Process {
        id: setProc
        stdout: StdioCollector {
            onStreamFinished: {
                // monitors.py prints the value it actually achieved.
                try {
                    const v = JSON.parse(text.trim());
                    if (typeof v === "number") {
                        const pending = Object.assign({}, root.pendingBrightness);
                        pending[setProc.command[3]] = v;
                        root.pendingBrightness = pending;
                    }
                } catch (e) { /* not JSON: keep the optimistic value */ }
            }
        }
        onExited: infoProc.running = true
    }

    function setMonitorScale(name: string, scale: real) {
        Quickshell.execDetached(["hyprctl", "keyword", "monitor",
            name + ",preferred,auto," + scale]);
        infoProc.running = true;
    }

    function setMonitorMode(name: string, mode: string) {
        const m = monitorList.find(x => x.name === name);
        const scale = m ? m.scale : 1;
        Quickshell.execDetached(["hyprctl", "keyword", "monitor",
            name + "," + mode + ",auto," + scale]);
        infoProc.running = true;
    }

    IpcHandler {
        target: "brightness"
        function get(): int { return root.level; }
        function set(v: string): void { root.setBrightness(parseInt(v)); }
    }
}
