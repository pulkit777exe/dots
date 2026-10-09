pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property string device: ""
    property int max: 1
    property int level: 0

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

    property bool pendingRead: false
    property bool floorNudged: false

    function read() {
        if (!available) return;
        if (readProc.running) pendingRead = true;
        else readProc.running = true;
    }

    Process {
        id: readProc
        command: ["brightnessctl", "-d", root.device, "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(",");
                if (p.length >= 5) {
                    const pct = parseInt(p[3]);
                    const mx = parseInt(p[4]);
                    if (!isNaN(pct) && !isNaN(mx) && mx > 0) {
                        root.max = mx;
                        root.level = Math.max(1, Math.min(100, pct));
                        if (pct < 1) {
                            if (!root.floorNudged) {
                                root.floorNudged = true;
                                root.setBrightness(1);
                            }
                        } else {
                            root.floorNudged = false;
                        }
                    }
                }
            }
        }
        onExited: {
            if (root.pendingRead) {
                root.pendingRead = false;
                root.read();
            }
        }
    }

    Process {
        id: watcher
        stdout: SplitParser { onRead: { if (readDebounce) readDebounce.restart(); } }
        onExited: if (root.available) retry.restart()
    }
    Timer { id: retry; interval: 3000; onTriggered: watcher.running = true }
    Timer { id: readDebounce; interval: 40; onTriggered: root.read() }

    Component.onCompleted: listProc.running = true

    property int pendingWrite: -1

    function setBrightness(pct: int) {
        if (!available) return;
        const v = Math.max(1, Math.min(100, Math.round(pct)));
        level = v;
        pendingWrite = v;
        writeDebounce.restart();
    }

    Timer {
        id: writeDebounce
        interval: 60
        onTriggered: {
            if (root.pendingWrite < 0 || writeProc.running) return;
            writeProc.command = ["brightnessctl", "-d", root.device, "set", String(root.pendingWrite) + "%"];
            root.pendingWrite = -1;
            writeProc.running = true;
        }
    }

    Process {
        id: writeProc
        onExited: {
            root.read();
            if (root.pendingWrite >= 0) writeDebounce.restart();
        }
    }

    function step(delta: int) { setBrightness(level + delta); }

    property var monitorList: []
    property var pendingBrightness: ({})

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
        onExited: (exitCode) => { if (exitCode !== 0) console.warn("Brightness: monitors.py info failed", exitCode) }
    }

    function monitorBrightness(name: string): real {
        if (pendingBrightness[name] !== undefined) return pendingBrightness[name];
        for (const m of monitorList) {
            if (m.name !== name) continue;
            if (m.brightness !== null && m.brightness !== undefined) return m.brightness;
            if (name.startsWith("eDP")) return level;
        }
        return 0;
    }

    property var pendingSet: ({})

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
                try {
                    const v = JSON.parse(text.trim());
                    if (typeof v === "number") {
                        const pending = Object.assign({}, root.pendingBrightness);
                        pending[setProc.command[3]] = v;
                        root.pendingBrightness = pending;
                    }
                } catch (e) {  }
            }
        }
        onExited: infoProc.running = true
    }

    function applyMonitor(name: string, mode: string, scale: real) {
        Quickshell.execDetached(["hyprctl", "eval",
            "hl.monitor({ output = \"" + name + "\", mode = \"" + mode
            + "\", position = \"auto\", scale = " + scale + " })"]);
        infoProc.running = true;
    }

    function setMonitorScale(name: string, scale: real) {
        root.applyMonitor(name, "preferred", scale);
    }

    function setMonitorMode(name: string, mode: string) {
        const m = monitorList.find(x => x.name === name);
        root.applyMonitor(name, mode, m ? m.scale : 1);
    }

    IpcHandler {
        target: "brightness"
        function get(): int { return root.level; }
        function set(v: string): void { root.setBrightness(parseInt(v)); }
    }
}
