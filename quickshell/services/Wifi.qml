pragma Singleton


import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Io
// The two nmcli halves live in services/wifi/, imported relatively. That is a
// subdirectory rather than two more files beside this one because services/
// carries a qmldir, and a type a qmldir-bearing directory does not list does
// not resolve -- services/../surfaces/cc is the same shape.
import "wifi"



Singleton {
    id: root

    // The AP list, and the only thing that asks for one.
    //
    // `busy` is the whole of `scanning`: scan(), the rescan's exit and the
    // settle timeout are three writers of one fact, so they write one
    // property in one place instead of three bools here that have to agree.
    readonly property bool scanning: prober.busy

    WifiScan {
        id: prober

        // NetworkManager's device, bound rather than passed per call so a
        // device that appears later is picked up with nothing to re-point.
        device: root.wifiDevice

        // The finished list, once per reply that carries one. What an empty
        // one means is Wifi.qml's call and not this file's: nmcli answering
        // with no APs is only believable when the radio is off.
        reported: (result) => {
            if (result.list.length === 0 && root.enabled) return;

            root.setNetworks(result.list);

            if (result.active) {
                root.connected = true;
                root.ssid = result.active.ssid;
                root.strength = result.active.strength;
            }
        }
    }

    // Every command that asks NetworkManager to do something. This file keeps
    // the decision and the answer; that one keeps the argv.
    WifiCommands {
        id: net

        requestRefresh: () => root.refreshStatus()

        radioResolved: (on) => {
            root.enabled = on;
        }
    }

    property bool enabled: true
    property bool connected: false
    property string ssid: ""
    property int strength: 0
    property var networks: []

    // Whether the AP list is actually on screen right now.
    //
    // The only thing that renders `networks` is the ControlCenter's wifi
    // page, and UiState already projects both facts needed to name it:
    // `controlCenterOpen` and `ccView`. So this reads the existing signal
    // rather than adding a `watching` flag of its own -- the same shape
    // PowerManager.qml uses, off the same singleton, because a service
    // should not need a second door knocked on by every surface.
    readonly property bool listVisible: UiState.controlCenterOpen && UiState.ccView === "wifi"

    // A repeating Timer does not fire on the tick that started it, so
    // without this the pane would render the list as it stood when it was
    // last closed rather than as it stands now.
    onListVisibleChanged: if (listVisible) refreshStatus();

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

    // Both halves of this are redundant on purpose. The property write asks
    // NetworkManager to change the radio and syncs `enabled` when it confirms;
    // the nmcli is the same request made the way NetworkManager's own
    // documentation says to, so a machine where no device object has been
    // found yet still ends up with the answer `nmcli` gave.
    function enableWifi(enable) {
        if (wifiDevice) {
            wifiDevice.enabled = enable;
        }
        net.radio(enable);
    }

    function scan() {
        prober.rescan();
    }

    function refreshStatus() {
        syncState();
        statusProc.running = true;
        prober.refresh();
    }

    function disconnect() {
        if (wifiDevice && wifiDevice.connected) {
            const nets = wifiDevice.networks;
            for (let i = 0; i < nets.count; i++) {
                const n = nets.get(i);
                if (n.connected) { n.disconnect(); return; }
            }
        }
        net.disconnect(root.activeInterface);
    }

    // The three below are Wifi.qml's public names, and they stay here: CcWifiPage
    // and ControlCenter.qml call the first two and `wifi connect` over IPC calls
    // the third. Each is now one line that hands the arguments over.
    function connectToNetwork(targetSsid, password, bssid) {
        net.connect(targetSsid, password, bssid, null);
    }

    function connectWireless(targetSsid, password, bssid, callback) {
        net.connect(targetSsid, password, bssid, callback);
    }

    function forgetNetwork(targetSsid) {
        net.forget(targetSsid);
    }

    // Both writers of `networks` go through here, and it stays here: the
    // NetworkManager seed in syncState() below is the other writer, and the
    // reason this is the only place either of them can write is that both
    // files call it rather than assigning.
    //
    // Assigning the array at all was the expensive half of the old 5s poll,
    // more than the fork: every assignment is a new array identity, so
    // `Wifi.networks` changed and `model: Wifi.networks.filter(...)` in
    // ControlCenter.qml was invalidated and re-diffed even when nmcli had
    // answered with a byte-identical AP list. Comparing first means an
    // unchanged poll now writes nothing and the Repeater is left alone.
    //
    // Compared as JSON rather than field by field on purpose. There is exactly
    // one writer of the full shape (WifiScan's listProc), so the key order is
    // stable from run to run, and a hand-written field list is a place to
    // silently forget a key and stop refreshing it -- `security` is read by
    // ControlCenter's activeNetwork/activeMeta and is precisely the kind of key
    // that gets left off such a list.
    function setNetworks(list) {
        const next = list || [];
        if (JSON.stringify(next) === JSON.stringify(root.networks)) return;
        root.networks = next;
    }

    function isConnectedState(state) {
        if (!state) return false;
        return state === "100 (connected)" || state === "connected" || state.startsWith("connected");
    }

    // The scalars only, and `networks` only as a seed.
    //
    // The AP list belongs to WifiScan.qml. `wifiDevice.networks` is a coarser
    // duplicate of the same APs -- no bssid, no security string -- and
    // assigning it over the top raced the nmcli parse on every single
    // refreshStatus(): within ~13ms of each tick the list flipped from the
    // enum-derived objects to the nmcli-derived ones. Two things were visible
    // from that. ControlCenter's activeSecurity reads `.security`, which only
    // the nmcli objects carry, so the connected line under the SSID read ""
    // and then "WPA2" twice per 5s tick. And the rows render
    // `modelData.strength + "%"`, which only the nmcli objects scale to 0-100
    // correctly, so they flickered to a wrong percentage.
    //
    // Note the two scales in one function. `WifiNetwork.signalStrength` is
    // NetworkManager's 0-1 fraction, so it is multiplied by 100 here and only
    // here; nmcli's `-g SIGNAL` column is already 0-100 and is read as it
    // stands in WifiScan.qml's parse(). Taking either on the other's scale
    // renders "0%"/"1%".
    //
    // Seeding while the list is empty keeps the nmcli-less fallback and ends
    // the race.
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
                    strength: Math.round(n.signalStrength * 100),
                    secured: n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Unknown,
                    active: n.connected
                });
                if (n.connected) {
                    root.ssid = n.name;
                    root.strength = Math.round(n.signalStrength * 100);
                    found = true;
                }
            }
            if (!found && !root.connected) {
                root.ssid = "";
                root.strength = 0;
            }
            if (list.length > 0 && root.networks.length === 0) setNetworks(list);
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

    // Not a 5s poll any more.
    //
    // `nmcli monitor` is already running and calls refreshStatus() on every
    // NetworkManager event, measured at 0.000% CPU over 40s, and monitorProc
    // restarts it 2s after it exits. The unconditional 5s timer was
    // re-deriving the same answer beside it: 23
    // `nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status` and 24
    // `nmcli -g ... d w` spawns per 120s measured off /proc, which is
    // ~33,840 forks/day and ~0.55% of a core, for nothing. It was not even a
    // scan: a warm `nmcli -g ... d w` is 13ms and returns the same 8 APs in
    // 426 bytes.
    //
    // Two timers rather than one Timer whose interval is rebound, because
    // reassigning `interval` on a running QML Timer restarts its countdown --
    // so toggling the pane would have kept resetting the backstop and could
    // starve it entirely.
    property int visiblePollIntervalMs: 5000

    // The backstop, and it is unconditional on purpose. monitorProc already
    // self-heals on exit, so what this covers is the narrower failure it
    // cannot: a monitor that is alive but has stopped reporting, which would
    // otherwise leave the bar icon and `qs ipc call wifi status` describing a
    // connection that no longer exists. 60s is the coarsest interval that
    // still heals that inside the time somebody waits before deciding the
    // shell is wedged, and it costs 2 forks/min -- 2,880/day against the
    // 33,840/day above.
    property int backstopPollIntervalMs: 60000

    // Neither timer sets triggeredOnStart. Component.onCompleted below
    // already calls refreshStatus() once at startup, and with it set the
    // shell opened by running the identical refresh twice.
    Timer {
        id: activePoll
        interval: root.visiblePollIntervalMs
        repeat: true
        running: root.listVisible
        onTriggered: root.refreshStatus()
    }

    Timer {
        id: backstopPoll
        interval: root.backstopPollIntervalMs
        repeat: true
        running: true
        onTriggered: root.refreshStatus()
    }

    Connections {
        target: wifiDevice
        function onEnabledChanged() { root.syncState() }
        function onConnectedChanged() { root.syncState(); }
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