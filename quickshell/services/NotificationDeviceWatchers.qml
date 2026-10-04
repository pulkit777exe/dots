// A device or a link changed state: the battery, the Bluetooth adapter, the
// Wi-Fi connection and the audio sink.
//
// One of the two leaves NotificationWatchers.qml is built from. Not a
// singleton, and nothing here owns a toast, a list or a timer: each
// Connections below decides that something happened and hands it to the
// fleet's `notify`.
//
// These four are together because they answer the same question the same way
// -- "what is this piece of hardware doing right now" -- and because each of
// them reads a live value off a service that only answers some time after the
// shell has loaded, so each of them has to swallow exactly its first change:
// the placeholder moving to the real state. Every one of those guards was
// measured rather than assumed, and the measurement is the comment on the
// handler. The watchers that need no guard are in
// NotificationActivityWatchers.qml, which is what makes the guard a property
// of the group rather than of the file it happens to sit in.
//
// A QtObject has no default property, so every Connections below is held in a
// property rather than written as a child -- otherwise the whole config fails
// with "Cannot assign to non-existent default property" (measured, and the
// same reason services/BrightnessMonitor.qml holds its Process and Timer that
// way).

import QtQuick
// For NotificationUrgency, which the two battery handlers below pass as the
// urgency of a low or critical toast.
//
// Measured, not assumed: a scratch config that called onBatteryLow() logged
// "ReferenceError: NotificationUrgency is not defined" against this file while
// it carried only `import QtQuick` above it. The ReferenceError is thrown
// while the argument list is being evaluated, so the handler never reached
// `notify` and the low-battery toast was not filed at all -- and because it
// happens inside a signal handler it cost one line in the log and nothing
// else. A QML import is per-file, so importing the module in the file that
// instantiates this one does not reach here.
import Quickshell.Services.Notifications

QtObject {
    id: root

    // The one capability this file needs: file a toast. Called as
    // `root.notify(...)` by every handler below.
    //
    // Assigned by NotificationWatchers.qml, always, at construction -- which is
    // why there is no null check here. The one gate for the whole fleet is that
    // file's announce(), so this file cannot hold an unwired `notify` in the
    // gap: the assignment is part of building this object, and no signal
    // handler runs until the event loop turns, which is after that.
    property var notify: null

    readonly property Connections battery: Connections {
        target: Battery

        property bool warnedLow: false
        property bool warnedCritical: false

        // No startup guard here, and that is measured rather than assumed.
        // `charging` is derived from the UPower device, and UPower answers
        // GetAll synchronously, so `charging` already holds the real state
        // the first time this handler can run: a scratch config logged 0
        // chargingChanged over 25s at startup, with `Battery.device`
        // non-null at t=0. A guard could only eat the first real plug of
        // every session. Bluetooth, Wifi and Volume below each measured 1
        // startup signal and do keep a guard.
        function onChargingChanged() {
            if (Battery.charging) {
                warnedLow = false
                warnedCritical = false
                root.notify(
                    "Charger Connected",
                    "Battery is now charging (" +
                    Battery.percentage +
                    "%)",
                    "Power",
                    "battery_charging_full"
                )
            } else {
                root.notify(
                    "Charger Disconnected",
                    "Running on battery power (" +
                    Battery.percentage +
                    "%)",
                    "Power",
                    "battery_alert"
                )
            }
        }

        function onBatteryLow() {
            if (warnedLow)
                return

            warnedLow = true

            root.notify(
                "Low Battery",

                Battery.percentage +
                "% remaining. Consider connecting a charger.",

                "Power",

                "battery_saver",

                NotificationUrgency.Critical
            )
        }

        function onBatteryCritical() {
            if (warnedCritical)
                return

            warnedCritical = true

            root.notify(
                "Critical Battery",

                Battery.percentage +
                "% remaining. Plug in immediately to avoid shutdown!",

                "Power",

                "battery_alert",

                NotificationUrgency.Critical
            )
        }
    }

    readonly property Connections bluetooth: Connections {
        target: Bluetooth

        // Load-bearing, and kept because it was measured to be. BlueZ
        // enumerates asynchronously, so `defaultAdapter` is null for the
        // first moments of the shell's life and `enabled` reads as the
        // placeholder false until the adapter answers. Measured: 1
        // enabledChanged, ~25ms after load. Without this guard every
        // session would announce a Bluetooth change nobody made.
        property bool seenStartupChange: false

        function onEnabledChanged() {
            if (!seenStartupChange) {
                seenStartupChange = true
                return
            }

            if (Bluetooth.enabled) {
                root.notify(
                    "Bluetooth Enabled",
                    "Bluetooth adapter turned on",
                    "Bluetooth",
                    "bluetooth"
                )
            } else {
                root.notify(
                    "Bluetooth Disabled",
                    "Bluetooth adapter turned off",
                    "Bluetooth",
                    "bluetooth_disabled"
                )
            }
        }
    }

    readonly property Connections wifi: Connections {
        target: Wifi

        // Load-bearing, and measured: `connected` starts false and is
        // first written by `syncState()` from Wifi's own
        // `Component.onCompleted`, so it flips to the real value a beat
        // after load. Measured: 1 connectedChanged, ~130ms after load.
        property bool seenStartupChange: false

        function onConnectedChanged() {
            if (!seenStartupChange) {
                seenStartupChange = true
                return
            }

            if (Wifi.connected) {
                root.notify(
                    "Wi-Fi Connected",
                    "Connected to " +
                    (Wifi.ssid || "network"),
                    "Network",
                    "wifi"
                )
            } else {
                root.notify(
                    "Wi-Fi Disconnected",
                    "Disconnected from network",
                    "Network",
                    "wifi_off"
                )
            }
        }
    }

    readonly property Connections volume: Connections {
        target: Volume

        // Load-bearing, and measured: `muted` is
        // `sinkAvailable ? sink.audio.muted : true`, so until Pipewire
        // hands over the default sink it reports the placeholder `true`
        // and then flips to the real value. Measured: 1 mutedChanged,
        // ~140ms after load.
        property bool seenStartupChange: false

        function onMutedChanged() {
            if (!seenStartupChange) {
                seenStartupChange = true
                return
            }

            if (Volume.muted) {
                root.notify(
                    "Audio Muted",
                    "Sound output muted",
                    "Audio",
                    "volume_mute"
                )
            } else {
                root.notify(
                    "Audio Unmuted",
                    "Sound output at " +
                    Volume.volumePercent +
                    "%",
                    "Audio",
                    "volume_up"
                )
            }
        }
    }
}