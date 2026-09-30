pragma Singleton


import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Io



Singleton {
    id: root

    
    property bool enabled: true
    property bool connected: false
    property string ssid: ""
    property int strength: 0
    property bool scanning: false
    property var networks: [] 
    
    
    property var ethernetInterfaces: []
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

    
    readonly property var devices: Networking.devices
    property var wifiDevice: null

    function findWifiDevice() {
        if (!devices) return null;
        for (let i = 0; i < devices.count; i++) {
            const d = devices.get(i);
            if (d && d.type === DeviceType.Wifi) return d;
        }
        return null;
    }

    
    function toggle() {
        enableWifi(!root.enabled);
    }

    function enableWifi(enable) {
        if (wifiDevice) {
            wifiDevice.enabled = enable;
        }
        toggleProc.cmdState = enable ? "on" : "off";
        toggleProc.running = true;
    }

    function scan() {
        root.scanning = true;
        if (wifiDevice) {
            wifiDevice.scannerEnabled = true;
            scanTimeout.restart();
        }
        rescanProc.running = true;
    }

    function refreshStatus() {
        syncState();
        statusProc.running = true;
        getNetworksProc.running = true;
    }

    function disconnect() {
        if (wifiDevice && wifiDevice.connected) {
            const nets = wifiDevice.networks;
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

    function syncState() {
        if (wifiDevice) {
            root.enabled = wifiDevice.enabled;
            root.connected = wifiDevice.connected;
            const nets = wifiDevice.networks;
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
                if (!foundConn && (!root.wifiDevice || !root.wifiDevice.connected)) {
                    root.connected = false;
                    root.ssid = "";
                }
                root.ethernetInterfaces = ethList;
            }
        }
    }

    
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

    
    Process {
        id: toggleProc
        property string cmdState: "on"
        command: ["nmcli", "radio", "wifi", cmdState]
        onExited: (code) => {
            root.enabled = (toggleProc.cmdState === "on");
            root.refreshStatus();
        }
    }

    
    Process {
        id: rescanProc
        command: ["nmcli", "dev", "wifi", "list", "--rescan", "yes"]
        onExited: {
            root.scanning = false;
            root.scanFinished();
            getNetworksProc.running = true;
        }
    }

    
    Process {
        id: disconnectProc
        command: ["nmcli", "device", "disconnect", root.activeInterface || "wifi"]
        onExited: root.refreshStatus()
    }

    
    Process {
        id: forgetProc
        property string ssidArg: ""
        command: ["nmcli", "connection", "delete", ssidArg]
        onExited: root.refreshStatus()
    }

    
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
            if (root.wifiDevice) root.wifiDevice.scannerEnabled = false;
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
        target: wifiDevice
        function onEnabledChanged() { root.syncState() }
        function onConnectedChanged() { root.syncState(); root.connectionChanged(); }
        function onNetworksChanged() { root.syncState() }
    }

    Connections {
        target: Networking.devices
        function onValuesChanged() {
            root.wifiDevice = root.findWifiDevice();
            root.syncState();
        }
    }

    Component.onCompleted: {
        wifiDevice = findWifiDevice();
        syncState();
        refreshStatus();
    }

    
    IpcHandler {
        target: "wifi"
        function status(): string { return JSON.stringify({enabled: root.enabled, connected: root.connected, ssid: root.ssid, strength: root.strength}); }
        function toggle(): void { root.toggle(); }
        function scan(): void { root.scan(); }
        function connect(ssid: string, password: string): void { root.connectToNetwork(ssid, password); }
        function disconnect(): void { root.disconnect(); }
    }
}
