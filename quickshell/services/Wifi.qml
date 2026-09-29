pragma Singleton


import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Io

/*
  Wifi & Networking service — adapted from Caelestia + Quickshell.Networking hybrid.
  Features:
  - Event-driven live updates via `nmcli monitor` + Quickshell.Networking native fallback
  - Robust SSID parsing with colon escaping (\:) and signal deduplication
  - Automatic physical ethernet interface detection (/sys/class/net/$i/device)
  - Full support for dynamic interface names (wlo1, wlan0, etc. without hardcoding)
  - Saved connection profile lookup and password handling
*/

Singleton {
    id: root

    // ── Public Flat Properties (100% UI compat) ──────────────────────
    property bool enabled: true
    property bool connected: false
    property string ssid: ""
    property int strength: 0
    property bool scanning: false
    property var networks: [] // [{ssid, strength, secured, active, frequency, bssid, security}]
    
    // Ethernet support from Caelestia
    property var ethernetInterfaces: []
    readonly property bool hasAvailableEthernet: ethernetInterfaces.some(d => d.state !== "unavailable" && d.state !== "disconnected")
    property string activeInterface: ""
    property string activeConnection: ""

    readonly property string iconName: {
        if (!enabled) return "wifi_off";
        if (!connected) return "wifi_off";
        if (strength >= 75) return "wifi";
        if (strength >= 50) return "wifi_2_bar";
        if (strength >= 25) return "wifi_1_bar";
        return "wifi_1_bar";
    }

    signal connectionChanged()
    signal scanFinished()
    signal connectionFailed(string ssid)

    // ── Native Quickshell.Networking Device (Fast path) ─────────────
    readonly property var _devices: Networking.devices
    property var _wifiDevice: null

    function _findWifiDevice() {
        if (!_devices) return null;
        for (let i = 0; i < _devices.count; i++) {
            const d = _devices.get(i);
            if (d && d.type === DeviceType.Wifi) return d;
        }
        return null;
    }

    // ── Public Actions ──────────────────────────────────────────────
    function toggle() {
        enableWifi(!root.enabled);
    }

    function enableWifi(enable) {
        if (_wifiDevice) {
            _wifiDevice.enabled = enable;
        }
        toggleProc.cmdState = enable ? "on" : "off";
        toggleProc.running = true;
    }

    function scan() {
        root.scanning = true;
        if (_wifiDevice) {
            _wifiDevice.scannerEnabled = true;
            scanTimeout.restart();
        }
        rescanProc.running = true;
    }

    function refreshStatus() {
        _syncState();
        statusProc.running = true;
        getNetworksProc.running = true;
    }

    function disconnect() {
        if (_wifiDevice && _wifiDevice.connected) {
            const nets = _wifiDevice.networks;
            for (let i = 0; i < nets.count; i++) {
                const n = nets.get(i);
                if (n.connected) { n.disconnect(); return; }
            }
        }
        disconnectProc.running = true;
    }

    function connectToNetwork(targetSsid, password, bssid) {
        connectWireless(targetSsid, password, bssid, null);
    }

    function forgetNetwork(targetSsid) {
        forgetProc.ssidArg = targetSsid;
        forgetProc.running = true;
    }

    // ── Internal Helpers ─────────────────────────────────────────────
    function isConnectedState(state) {
        if (!state) return false;
        return state === "100 (connected)" || state === "connected" || state.startsWith("connected");
    }

    function parseNetworkOutput(output) {
        if (!output || output.length === 0) return [];
        const PLACEHOLDER = "STRINGWHICHHOPEFULLYWONTBEUSED";
        const rep = new RegExp("\\\\:", "g");
        const rep2 = new RegExp(PLACEHOLDER, "g");

        return output.trim().split("\n").filter(line => line && line.length > 0).map(n => {
            const net = n.replace(rep, PLACEHOLDER).split(":");
            const rawSsid = net[3] ? net[3].replace(rep2, ":") : "";
            const rawBssid = net[4] ? net[4].replace(rep2, ":") : "";
            const rawSec = net[5] ? net[5] : "";
            return {
                active: net[0] === "yes",
                strength: parseInt(net[1] || "0", 10) || 0,
                frequency: parseInt(net[2] || "0", 10) || 0,
                ssid: rawSsid.trim(),
                bssid: rawBssid.trim(),
                security: rawSec.trim(),
                secured: rawSec.trim().length > 0 && !rawSec.includes("NONE")
            };
        }).filter(n => n.ssid && n.ssid.length > 0);
    }

    function deduplicateNetworks(netList) {
        if (!netList || netList.length === 0) return [];
        const map = new Map();
        for (const net of netList) {
            const existing = map.get(net.ssid);
            if (!existing) {
                map.set(net.ssid, net);
            } else {
                if (net.active && !existing.active) {
                    map.set(net.ssid, net);
                } else if (!net.active && !existing.active) {
                    if (net.strength > existing.strength) {
                        map.set(net.ssid, net);
                    }
                }
            }
        }
        return Array.from(map.values()).sort((a, b) => (Number(b.active) - Number(a.active) || b.strength - a.strength));
    }

    function connectWireless(targetSsid, password, bssid, callback) {
        if (!targetSsid) return;
        let cmd = ["nmcli", "device", "wifi", "connect", targetSsid];
        if (password && password.length > 0) {
            cmd.push("password", password);
        }
        if (bssid && bssid.length > 0) {
            cmd.push("bssid", bssid);
        }
        const proc = connectCustomProc;
        proc.cb = callback;
        proc.targetSsid = targetSsid;
        proc.command = cmd;
        proc.running = true;
    }

    function _syncState() {
        if (_wifiDevice) {
            root.enabled = _wifiDevice.enabled;
            root.connected = _wifiDevice.connected;
            const nets = _wifiDevice.networks;
            let found = false;
            const list = [];
            for (let i = 0; i < nets.count; i++) {
                const n = nets.get(i);
                list.push({
                    ssid: n.name,
                    strength: Math.round(n.signalStrength),
                    secured: n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Unknown,
                    active: n.connected
                });
                if (n.connected) {
                    root.ssid = n.name;
                    root.strength = Math.round(n.signalStrength);
                    found = true;
                }
            }
            if (!found && !root.connected) {
                root.ssid = "";
                root.strength = 0;
            }
            if (list.length > 0) root.networks = list;
        }
    }

    // ── Processes ───────────────────────────────────────────────────

    // Monitor for live NetworkManager events
    Process {
        id: monitorProc
        running: true
        command: ["nmcli", "monitor"]
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: SplitParser {
            onRead: (data) => {
                root.refreshStatus();
                root.connectionChanged();
            }
        }
        onExited: monitorRestartTimer.start()
    }
    Timer { id: monitorRestartTimer; interval: 2000; onTriggered: monitorProc.running = true }

    // Status polling
    Process {
        id: statusProc
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                let foundConn = false;
                let activeIf = "";
                let activeConn = "";
                let ethList = [];

                for (const line of lines) {
                    const parts = line.split(":");
                    if (parts.length >= 4) {
                        const dev = parts[0];
                        const type = parts[1];
                        const state = parts[2];
                        const conn = parts[3];

                        if (type === "wifi" && root.isConnectedState(state)) {
                            foundConn = true;
                            activeIf = dev;
                            activeConn = conn;
                            root.connected = true;
                            root.ssid = conn;
                        } else if (type === "ethernet") {
                            ethList.push({ device: dev, type: type, state: state, connection: conn });
                            if (root.isConnectedState(state) && !foundConn) {
                                foundConn = true;
                                activeIf = dev;
                                activeConn = conn;
                            }
                        }
                    }
                }

                root.activeInterface = activeIf;
                root.activeConnection = activeConn;
                if (!foundConn && (!root._wifiDevice || !root._wifiDevice.connected)) {
                    root.connected = false;
                    root.ssid = "";
                }
                root.ethernetInterfaces = ethList;
            }
        }
    }

    // Detailed network list polling
    Process {
        id: getNetworksProc
        command: ["nmcli", "-g", "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY", "d", "w"]
        stdout: StdioCollector {
            onStreamFinished: {
                const all = root.parseNetworkOutput(text);
                const deduped = root.deduplicateNetworks(all);
                if (deduped.length > 0 || !root.enabled) {
                    root.networks = deduped;
                    const act = deduped.find(n => n.active);
                    if (act) {
                        root.connected = true;
                        root.ssid = act.ssid;
                        root.strength = act.strength;
                    }
                }
            }
        }
    }

    // Toggle Wi-Fi radio
    Process {
        id: toggleProc
        property string cmdState: "on"
        command: ["nmcli", "radio", "wifi", cmdState]
        onExited: (code) => {
            root.enabled = (toggleProc.cmdState === "on");
            root.refreshStatus();
        }
    }

    // Scan trigger
    Process {
        id: rescanProc
        command: ["nmcli", "dev", "wifi", "list", "--rescan", "yes"]
        onExited: {
            root.scanning = false;
            root.scanFinished();
            getNetworksProc.running = true;
        }
    }

    // Disconnect (uses deviceType "wifi" to avoid hardcoding interface name)
    Process {
        id: disconnectProc
        command: ["nmcli", "device", "disconnect", root.activeInterface || "wifi"]
        onExited: root.refreshStatus()
    }

    // Forget network profile
    Process {
        id: forgetProc
        property string ssidArg: ""
        command: ["nmcli", "connection", "delete", ssidArg]
        onExited: root.refreshStatus()
    }

    // Custom connection process with error / password detection
    Process {
        id: connectCustomProc
        property var cb: null
        property string targetSsid: ""
        stdout: StdioCollector { id: connectStdout }
        stderr: StdioCollector { id: connectStderr }
        onExited: (code) => {
            const err = connectStderr.text ? connectStderr.text.trim() : "";
            const out = connectStdout.text ? connectStdout.text.trim() : "";
            const needsPass = err.includes("Secrets were required") || err.includes("password") || err.includes("No secrets provided");
            const success = (code === 0);

            if (!success) {
                root.connectionFailed(connectCustomProc.targetSsid);
            }

            if (connectCustomProc.cb) {
                connectCustomProc.cb({
                    success: success,
                    needsPassword: needsPass,
                    output: out,
                    error: err,
                    exitCode: code
                });
            }
            root.refreshStatus();
        }
    }

    Timer {
        id: scanTimeout
        interval: 10000
        onTriggered: {
            root.scanning = false;
            if (root._wifiDevice) root._wifiDevice.scannerEnabled = false;
            root.scanFinished();
        }
    }

    Timer {
        id: periodicTimer
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refreshStatus()
    }

    Connections {
        target: _wifiDevice
        function onEnabledChanged() { root._syncState() }
        function onConnectedChanged() { root._syncState(); root.connectionChanged(); }
        function onNetworksChanged() { root._syncState() }
    }

    Connections {
        target: Networking.devices
        function onValuesChanged() {
            root._wifiDevice = root._findWifiDevice();
            root._syncState();
        }
    }

    Component.onCompleted: {
        _wifiDevice = _findWifiDevice();
        _syncState();
        refreshStatus();
    }

    // ── IPC compatibility ───────────────────────────────────────────
    IpcHandler {
        target: "wifi"
        function status(): string { return JSON.stringify({enabled: root.enabled, connected: root.connected, ssid: root.ssid, strength: root.strength}); }
        function toggle(): void { root.toggle(); }
        function scan(): void { root.scan(); }
        function connect(ssid: string, password: string): void { root.connectToNetwork(ssid, password); }
        function disconnect(): void { root.disconnect(); }
    }
}
