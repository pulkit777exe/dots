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

    // Reads coalesce: a repeating fn key changes the backlight faster than
    // brightnessctl answers, and a read requested while one is in flight
    // would be dropped, leaving the last step of a burst unread. The burst
    // becomes one debounced read; pendingRead replays it when the running
    // one drains.
    property bool pendingRead: false
    property bool floorNudged: false   // one hardware nudge per dip below 1

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
                // brightnessctl -m: device,class,current,percent,max -- the
                // percent field is what we want; dividing current by it used
                // to pin level to a constant 96000 (max/100*100), which froze
                // every UI bound to it.
                const p = text.trim().split(",");
                if (p.length >= 5) {
                    const pct = parseInt(p[3]);
                    const mx = parseInt(p[4]);
                    if (!isNaN(pct) && !isNaN(mx) && mx > 0) {
                        root.max = mx;
                        // Floor of 1: an external writer can still land on
                        // 0, which leaves the panel black. Show the floor at
                        // once and nudge the hardware back up; the lock
                        // clears as soon as a read sees a legal value, so a
                        // failed nudge cannot loop.
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

    // External changes (fn keys, other tools) arrive as one path line each.
    Process {
        id: watcher
        // `readDebounce` can resolve undefined if a queued line lands while
        // an old engine generation is being torn down -- guard instead of
        // throwing.
        stdout: SplitParser { onRead: { if (readDebounce) readDebounce.restart(); } }
        onExited: if (root.available) retry.restart()
    }
    Timer { id: retry; interval: 3000; onTriggered: watcher.running = true }
    Timer { id: readDebounce; interval: 40; onTriggered: root.read() }

    Component.onCompleted: listProc.running = true

    // ---- write ---------------------------------------------------------------

    // A drag or a held key fires faster than brightnessctl writes, and
    // setting Process.running while it is already running is a no-op -- the
    // command would be swapped out from under the live process and the
    // write lost, which reads back as a slider that snaps back. Keep only
    // the newest target; an in-flight write drains into it on exit.
    property int pendingWrite: -1

    function setBrightness(pct: int) {
        if (!available) return;
        const v = Math.max(1, Math.min(100, Math.round(pct)));
        level = v;   // optimistic; read() corrects if the write was refused
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
        onExited: (exitCode) => { if (exitCode !== 0) console.warn("Brightness: monitors.py info failed", exitCode) }
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

    // `hyprctl keyword` is dead on the 0.56 lua config ("keyword can't work
    // with non-legacy parsers"); `eval` takes lua instead, and hl.monitor
    // applies the rule live, same as the old keyword did.
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
