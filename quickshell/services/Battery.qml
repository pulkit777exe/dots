pragma Singleton
// qmllint disable import

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

/*
  Battery service.

  UPower/Quickshell.Services.UPower is dbus-signal driven already — no
  polling required. This wraps the primary "display device" (the one
  UPower itself aggregates across all batteries) into flat properties,
  plus a couple of derived conveniences (icon name, low-battery signal)
  that surfaces care about.
*/

Singleton {
    id: root

    readonly property bool available: UPower.displayDevice !== null
    readonly property var device: UPower.displayDevice

    // UPowerDevice.percentage is documented as 0-100, but some Quickshell builds expose 0-1 (e.g. 0.8 → round=1, seen live as 1% vs 80% upower). Handle both.
    readonly property int percentage: {
        if (!device) return 0;
        const p = device.percentage;
        if (p <= 1.0) return Math.round(p * 100);
        return Math.round(p);
    }
    readonly property bool charging: device ? (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.PendingCharge || device.state === UPowerDeviceState.FullyCharged) : false
    readonly property bool plugged: device ? (device.state !== UPowerDeviceState.Discharging) : true
    readonly property bool isLaptopBattery: available

    // seconds -> null when unknown/charging fully etc.
    readonly property real timeToEmpty: device ? device.timeToEmpty : 0
    readonly property real timeToFull: device ? device.timeToFull : 0

    readonly property bool low: available && !plugged && percentage <= 20
    readonly property bool critical: available && !plugged && percentage <= 5

    // Semantic status slug (logging/tooltips) — NOT a Material ligature.
    // For a glyph, bind components/BatteryIcon.qml to percentage/charging/available.
    readonly property string iconName: {
        if (!available) return "battery-missing";
        if (charging) return "battery-charging";
        if (percentage >= 90) return "battery-full";
        if (percentage >= 60) return "battery-good";
        if (percentage >= 30) return "battery-medium";
        if (percentage >= 15) return "battery-low";
        return "battery-empty";
    }

    signal batteryLow()
    signal batteryCritical()

    onLowChanged: if (low) batteryLow()
    onCriticalChanged: if (critical) batteryCritical()

    function formattedTimeRemaining() {
        const secs = charging ? timeToFull : timeToEmpty;
        if (!secs || secs <= 0) return "";
        const h = Math.floor(secs / 3600);
        const m = Math.round((secs % 3600) / 60);
        if (h > 0) return h + "h " + m + "m";
        return m + "m";
    }

    IpcHandler {
        target: "battery"
        function getStatus(): string { return JSON.stringify({available: root.available, percentage: root.percentage, charging: root.charging, low: root.low, critical: root.critical}); }
        function getPercentage(): int { return root.percentage; }
        function isCharging(): bool { return root.charging; }
    }
}
