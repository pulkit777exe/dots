pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io



Singleton {
    id: root

    
    property bool enabled: false
    property bool scanning: false
    property var devices: [] 

    readonly property var connectedDevices: devices.filter(d => d.connected)
    readonly property var connectedDevice: connectedDevices.length > 0 ? connectedDevices[0] : null
    readonly property string connectedName: connectedDevice ? (connectedDevice.name || connectedDevice.mac) : ""

    readonly property string iconName: {
        if (!enabled) return "bluetooth_disabled";
        if (connectedDevices.length > 0) return "bluetooth_connected";
        return "bluetooth";
    }

    signal stateChanged()
    signal deviceConnected(string mac, string name)
    signal deviceDisconnected(string mac)

    
    function toggle() {
        const next = !root.enabled;
        btToggleProc.powerState = next ? "on" : "off";
        btToggleProc.running = true;
    }

    function scan() {
        root.scanning = true;
        btScanProc.running = true;
        scanTimeout.restart();
    }

    function refresh() {
        btPollProc.running = true;
    }

    function connectDevice(mac) {
        btConnectProc.macArg = mac;
        btConnectProc.running = true;
    }

    function disconnectDevice(mac) {
        btDisconnectProc.macArg = mac;
        btDisconnectProc.running = true;
    }

    function pair(mac) {
        btPairProc.macArg = mac;
        btPairProc.running = true;
    }

    function forget(mac) {
        btForgetProc.macArg = mac;
        btForgetProc.running = true;
    }

    
    Process {
        id: btPollProc
        command: ["sh", "-c", "bluetoothctl show && echo '---' && bluetoothctl devices && echo '---' && bluetoothctl devices Connected"]
        stdout: StdioCollector {
            id: btCollector
            onStreamFinished: {
                let rawText = (btCollector.text || "").trim();
                if (!rawText) return;
                let parts = rawText.split("---");

                if (parts.length >= 1) {
                    let p = parts[0].trim();
                    let isPowered = p.includes("Powered: yes");
                    let isDiscovering = p.includes("Discovering: yes");
                    if (root.enabled !== isPowered) root.enabled = isPowered;
                    root.scanning = isDiscovering;
                }

                let connectedMacs = new Set();
                if (parts.length >= 3) {
                    let connLines = parts[2].trim().split("\n");
                    for (let l of connLines) {
                        let match = l.trim().match(/^Device\s+([0-9A-Fa-f:]+)/);
                        if (match) connectedMacs.add(match[1]);
                    }
                }

                let allDevs = [];
                if (parts.length >= 2) {
                    let devLines = parts[1].trim().split("\n");
                    for (let l of devLines) {
                        let match = l.trim().match(/^Device\s+([0-9A-Fa-f:]+)\s+(.+)$/);
                        if (match) {
                            let mac = match[1];
                            let name = match[2];
                            let isConn = connectedMacs.has(mac);
                            allDevs.push({
                                mac: mac,
                                name: name,
                                paired: true,
                                connected: isConn,
                                trusted: true
                            });
                        }
                    }
                }

                
                allDevs.sort((a, b) => (Number(b.connected) - Number(a.connected) || Number(b.paired) - Number(a.paired) || a.name.localeCompare(b.name)));
                root.devices = allDevs;
                root.stateChanged();
            }
        }
    }

    
    Process {
        id: btToggleProc
        property string powerState: "on"
        command: ["bluetoothctl", "power", powerState]
        onExited: btPollTimer.restart()
    }

    Process {
        id: btScanProc
        command: ["bluetoothctl", "scan", "on"]
        onExited: btPollTimer.restart()
    }

    Process {
        property string macArg: ""
        id: btConnectProc
        command: ["bluetoothctl", "connect", macArg]
        onExited: btPollTimer.restart()
    }

    Process {
        property string macArg: ""
        id: btDisconnectProc
        command: ["bluetoothctl", "disconnect", macArg]
        onExited: btPollTimer.restart()
    }

    Process {
        property string macArg: ""
        id: btPairProc
        command: ["bluetoothctl", "pair", macArg]
        onExited: btPollTimer.restart()
    }

    Process {
        property string macArg: ""
        id: btForgetProc
        command: ["bluetoothctl", "remove", macArg]
        onExited: btPollTimer.restart()
    }

    
    Timer {
        id: scanTimeout
        interval: 15000
        onTriggered: {
            root.scanning = false;
            Quickshell.execDetached(["bluetoothctl", "scan", "off"]);
        }
    }

    
    Timer {
        id: btPollTimer
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: btPollProc.running = true
    }

    Component.onCompleted: {
        btPollProc.running = true;
    }

    
    IpcHandler {
        target: "bluetooth"
        function toggle(): void { root.toggle(); }
        function scan(): void { root.scan(); }
        function refresh(): void { root.refresh(); }
        function connect(mac: string): void { root.connectDevice(mac); }
        function disconnect(mac: string): void { root.disconnectDevice(mac); }
    }
}