pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// The battery the island badge draws. UPower pushes every change; nothing
// here polls.

Singleton {
    id: root

    readonly property bool available: UPower.displayDevice !== null
    readonly property var device: UPower.displayDevice

    // Accept either scale: UPower reports 0..100, but a 0..1 reading has
    // shown up in practice and would otherwise render as "1%".
    readonly property int percentage: {
        if (!device) return 0;
        const p = device.percentage;
        return Math.round(p <= 1.0 ? p * 100 : p);
    }

    readonly property bool charging: device
        ? (device.state === UPowerDeviceState.Charging
            || device.state === UPowerDeviceState.PendingCharge
            || device.state === UPowerDeviceState.FullyCharged)
        : false

    readonly property bool plugged: device ? device.state !== UPowerDeviceState.Discharging : true
}
