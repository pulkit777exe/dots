pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool enabled: false
    property bool connected: false
    property string ssid: ""
    property int strength: 0
    property bool busy: false
    property var networks: []

    readonly property string iconName: {
        if (!enabled) return "wifi_off";
        if (!connected) return "wifi";
        if (strength >= 75) return "wifi";
        if (strength >= 40) return "wifi_2_bar";
        return "wifi_1_bar";
    }

    readonly property string subtitle: {
        if (!enabled) return "Off";
        if (!connected) return "Not connected";
        return ssid;
    }

    Process {
        id: refresh
        command: ["bash", "-c",
            "nmcli radio wifi; " +
            "nmcli -t -f TYPE,STATE,CONNECTION device status | grep '^wifi:'; " +
            "nmcli -t -f ACTIVE,SSID,SECURITY,SIGNAL dev wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                let sawDevice = false;
                let sawActive = false;
                const nets = [];
                for (const raw of text.split("\n")) {
                    const line = raw.trim();
                    if (line === "enabled" || line === "disabled") {
                        root.enabled = line === "enabled";
                    } else if (line.startsWith("wifi:") && !sawDevice) {
                        sawDevice = true;
                        const body = line.slice(5).replace(/\\:/g, "\u0001");
                        const parts = body.split(":");
                        const state = parts[0];
                        const conn = parts.slice(1).join(":").replace(/\u0001/g, ":").trim();
                        root.connected = state.startsWith("connected");
                        root.ssid = root.connected ? conn : "";
                    } else if (line.startsWith("yes:") || line.startsWith("no:")) {
                        const f = root.splitEscaped(line);
                        const active = f[0] === "yes";
                        const ssid = (f[1] || "").trim();
                        const security = (f[2] || "").trim();
                        const signal = parseInt(f[3]) || 0;
                        if (ssid.length === 0) continue;
                        if (active && !sawActive) { sawActive = true; root.strength = signal; }
                        const prev = nets.findIndex(n => n.ssid === ssid);
                        const net = { ssid: ssid, active: active,
                                      secured: security.length > 0 && security !== "--",
                                      signal: signal };
                        if (prev < 0) nets.push(net);
                        else if (active || signal > nets[prev].signal) nets[prev] = net;
                    }
                }
                if (!sawDevice) { root.connected = false; root.ssid = ""; }
                if (!sawActive) root.strength = 0;
                if (!root.enabled) { root.connected = false; root.ssid = ""; root.strength = 0; }
                nets.sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
                root.networks = nets;
            }
        }
    }

    function splitEscaped(line): var {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) { cur += line[++i]; }
            else if (c === ":") { out.push(cur); cur = ""; }
            else cur += c;
        }
        out.push(cur);
        return out;
    }

    Timer {
        id: refreshDebounce
        interval: 300
        onTriggered: refresh.running = true
    }
    function requestRefresh() { refreshDebounce.restart(); }

    Process {
        id: monitor
        command: ["nmcli", "monitor"]
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: SplitParser { onRead: root.requestRefresh() }
        onExited: monitorRetry.restart()
    }
    Timer { id: monitorRetry; interval: 2000; onTriggered: monitor.running = true }

    Timer { interval: 60000; repeat: true; running: true; onTriggered: refresh.running = true }

    Component.onCompleted: {
        monitor.running = true;
        refresh.running = true;
    }

    function toggle() {
        enabledCmd.command = ["nmcli", "radio", "wifi", enabled ? "off" : "on"];
        enabledCmd.running = true;
    }
    Process {
        id: enabledCmd
        onExited: root.requestRefresh()
    }

    function scan() {
        busy = true;
        scanProc.running = true;
    }
    Process {
        id: scanProc
        command: ["nmcli", "dev", "wifi", "list", "--rescan", "yes"]
        onExited: { root.busy = false; root.requestRefresh(); }
    }

    function connect(ssid: string, password: string) {
        busy = true;
        connectProc.command = password && password.length > 0
            ? ["nmcli", "device", "wifi", "connect", ssid, "password", password]
            : ["nmcli", "device", "wifi", "connect", ssid];
        connectProc.running = true;
    }
    Process {
        id: connectProc
        stderr: StdioCollector { id: connectErr }
        onExited: {
            root.busy = false;
            root.requestRefresh();
            if (code !== 0) console.warn("Wifi: connect failed:", connectErr.text.trim());
        }
    }

    function disconnect() {
        disconnectProc.running = true;
    }
    Process {
        id: disconnectProc
        command: ["nmcli", "device", "disconnect", "wifi"]
        onExited: root.requestRefresh()
    }

    IpcHandler {
        target: "wifi"
        function status(): string {
            return JSON.stringify({ enabled: root.enabled, connected: root.connected, ssid: root.ssid, strength: root.strength });
        }
        function toggle(): void { root.toggle(); }
        function scan(): void { root.scan(); }
        function connect(ssid: string, password: string): void { root.connect(ssid, password); }
        function disconnect(): void { root.disconnect(); }
    }
}
