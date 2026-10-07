pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth as Bt

// Bluetooth, straight off BlueZ -- no processes, no polling. The adapter is
// genuinely null for the first second while BlueZ enumerates; everything
// here no-ops until it arrives.

Singleton {
    id: root

    readonly property var adapter: Bt.Bluetooth.defaultAdapter
    readonly property bool enabled: adapter ? adapter.enabled : false
    readonly property bool scanning: adapter ? adapter.discovering : false
    readonly property string name: adapter ? (adapter.alias || adapter.deviceName || "") : ""

    // BlueZ returns D-Bus object order, which means nothing: connected
    // devices first, then paired, then alphabetical.
    readonly property var devices: (adapter?.devices?.values ?? [])
        .map(d => ({
            mac: d.address,
            name: d.name || d.deviceName || d.address,
            paired: d.paired,
            connected: d.connected,
            trusted: d.trusted,
        }))
        .sort((a, b) => (Number(b.connected) - Number(a.connected)
            || Number(b.paired) - Number(a.paired)
            || a.name.localeCompare(b.name)));

    readonly property var nearbyDevices: devices.filter(d => !d.paired)
    readonly property string connectedName: {
        const c = devices.find(d => d.connected);
        return c ? c.name : "";
    }

    readonly property string iconName: {
        if (!enabled) return "bluetooth_disabled";
        return connectedName.length > 0 ? "bluetooth_connected" : "bluetooth";
    }

    function toggle() {
        if (adapter) adapter.enabled = !adapter.enabled;
    }

    function scan() {
        if (!adapter) return;
        adapter.discovering = true;
        scanWindow.restart();
    }

    // Discovery runs until told to stop, so it gets a window of its own.
    Timer {
        id: scanWindow
        interval: 15000
        onTriggered: { if (root.adapter && root.enabled) root.adapter.discovering = false; }
    }

    function findDevice(mac) {
        if (!adapter) return null;
        const want = String(mac).toLowerCase();
        for (const d of adapter.devices.values)
            if (String(d.address).toLowerCase() === want) return d;
        return null;
    }

    function connectDevice(mac) { const d = findDevice(mac); if (d) d.connect(); }
    function disconnectDevice(mac) { const d = findDevice(mac); if (d) d.disconnect(); }
    function pair(mac) { const d = findDevice(mac); if (d) d.pair(); }
}
