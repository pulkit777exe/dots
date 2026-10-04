pragma Singleton


import QtQuick
import Quickshell
// Aliased because this file *is* the `Bluetooth` singleton. Unaliased it still
// resolves, but `Bluetooth.defaultAdapter` then reads as a self-reference.
import Quickshell.Bluetooth as Bt
// IpcHandler comes from Quickshell.Io, not Quickshell. Nothing else in this
// file uses that module, so it reads as unused and gets deleted -- which takes
// the whole singleton down, because every other service imports it too.
import Quickshell.Io



// Bluetooth -- a view over stock `Quickshell.Bluetooth` (BlueZ over D-Bus).
// No process, no poll, no text to parse: every property below is a binding on
// a BlueZ signal, so it updates only when BlueZ says something changed.
//
// Properties
//   enabled           adapter is powered. Default false, which is also the
//                     state before BlueZ has answered at all.
//   scanning          adapter is discovering.
//   devices           every device the adapter knows, as
//                     { mac, name, paired, connected, trusted }. The one
//                     place the module's names are translated for the views.
//   nearbyDevices     devices that are not paired -- what Nearby shows.
//   connectedDevices  every connected device, connected first.
//   connectedDevice   first connected device, or null.
//   connectedName     that device's name, "" when nothing is connected.
//   iconName          bluetooth_disabled | bluetooth_connected | bluetooth.
//
// There is no change signal, and a view needs none: every property above is a
// binding on a BlueZ signal, so anything bound to one has already re-evaluated
// by the time BlueZ's notification returns. A `stateChanged` used to be emitted
// here and had no consumer in the tree -- grep `onStateChanged` for that claim
// before adding one back.
//
// There is no `discovered` list any more. It existed only because
// `bluetoothctl devices` reads BlueZ's on-disk cache -- paired hardware only
// -- so a stranger had nowhere to appear. The object manager reports a newly
// seen device the moment it is seen, paired or not, so `devices` and
// `nearbyDevices` together cover what the two lists used to. Verified on this
// machine: with `scanning` on, an unpaired device appeared in `devices` and
// therefore in `nearbyDevices`, and `devices` stays the whole known set.
//
// Error states
//   No adapter -- no hardware, no bluetoothd, or BlueZ not reachable yet.
//   Every property falls back to its default and every function is a no-op.
//   Nothing throws. BlueZ enumerates asynchronously, so `defaultAdapter` is
//   genuinely null for roughly the first second of the shell's life; that is
//   the normal path, not an error.
//
// Known gap: pairing agents. Quickshell 0.3.1 exposes no `org.bluez.Agent1`
// (confirmed against the installed binary -- no Agent1, PIN, or passkey
// symbols in it), so `pair()` cannot answer a device that wants a PIN or a
// passkey. That is not a regression: the old `bluetoothctl pair` ran as a
// detached Process with no terminal, so it could not answer one either. A
// device that only needs a confirmation on its own side -- the common case --
// pairs through this path unchanged.

Singleton {
    id: root

    readonly property var adapter: Bt.Bluetooth.defaultAdapter

    readonly property bool enabled: adapter ? adapter.enabled : false
    readonly property bool scanning: adapter ? adapter.discovering : false

    // `name` is the user's alias where one is set, so it wins over the name the
    // device reports. `devices` is sorted because BlueZ returns D-Bus object
    // order, which means nothing.
    readonly property var devices: (adapter?.devices?.values ?? []).map(d => ({
        mac: d.address,
        name: d.name || d.deviceName || d.address,
        paired: d.paired,
        connected: d.connected,
        trusted: d.trusted
    })).sort((a, b) => (Number(b.connected) - Number(a.connected)
        || Number(b.paired) - Number(a.paired)
        || a.name.localeCompare(b.name)));

    readonly property var connectedDevices: devices.filter(d => d.connected)
    readonly property var connectedDevice: connectedDevices.length > 0 ? connectedDevices[0] : null
    readonly property string connectedName: connectedDevice ? connectedDevice.name : ""

    // Pairing is what moves a device out of Nearby: it stays in `devices`, but
    // as a paired one.
    readonly property var nearbyDevices: devices.filter(d => !d.paired)

    readonly property string iconName: {
        if (!enabled) return "bluetooth_disabled";
        if (connectedDevices.length > 0) return "bluetooth_connected";
        return "bluetooth";
    }

    // Every mac arrives from QML or from `qs ipc call`, so the shape is
    // checked once here: a miss is a no-op instead of a BlueZ error, and
    // nothing else in the file has to think about it.
    function findDevice(mac) {
        const want = String(mac).toLowerCase();
        if (!/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/.test(want)) return null;
        const list = adapter ? adapter.devices.values : [];
        for (const d of list) {
            if (String(d.address).toLowerCase() === want) return d;
        }
        return null;
    }

    function toggle() {
        if (!adapter) return;
        adapter.enabled = !adapter.enabled;
    }

    function scan() {
        if (!adapter) return;
        adapter.discovering = true;
        // Discovery keeps the radio busy until it is told to stop, and nothing
        // else in the shell ever would.
        scanWindow.restart();
    }

    // Kept because `bluetooth refresh` and the control centre's Bluetooth pill
    // both call it on the way into the page. BlueZ pushes every change, so
    // there is nothing left to re-read.
    function refresh() {}

    function connectDevice(mac) {
        const d = findDevice(mac);
        if (d) d.connect();
    }

    function disconnectDevice(mac) {
        const d = findDevice(mac);
        if (d) d.disconnect();
    }

    function pair(mac) {
        const d = findDevice(mac);
        if (d) d.pair();
    }

    function forget(mac) {
        const d = findDevice(mac);
        if (d) d.forget();
    }

    Timer {
        id: scanWindow
        interval: 15000
        // Powered off mid-window: a down adapter is not discovering, and the
        // write would be a guaranteed BlueZ rejection.
        onTriggered: { if (root.adapter && root.enabled) root.adapter.discovering = false; }
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