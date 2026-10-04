// Every other service's state change that turns into a toast: battery, the
// Bluetooth and Wi-Fi adapters, the power profile, night light, the
// keep-awake inhibitor, the theme, volume, what MPRIS is playing, and the
// clipboard.
//
// One of three files split out of services/Notifications.qml. Not a singleton.
// The other two are NotificationState.qml (the toast list) and
// NotificationHistory.qml (the disk).
//
// This file exists because "announce system events" is a different job from
// "hold toasts". It has no list, no timers and no disk of its own: it decides
// that something happened and asks NotificationState to file a toast, and
// nothing here can dismiss one.
//
// The ten Connections live in the two files below, and this file is what holds
// them together with the one capability they are all handed:
//
//   NotificationDeviceWatchers.qml   a piece of hardware or a link changed
//                                    state: battery, Bluetooth, Wi-Fi, volume.
//                                    Each of those four reads a value that only
//                                    arrives some time after load, which is why
//                                    each of them carries a measured startup
//                                    guard.
//   NotificationActivityWatchers.qml  something happened rather than something
//                                    connected: a setting changed, a track
//                                    changed, something was copied.
//
// The split is by what the toast is about, not by what the line count was.
// Filing a toast is the same three lines in both leaves; what differs is which
// service owns the signal, and which file you read to answer "why does this
// one swallow its first change".
//
// A QtObject has no default property, so the two fleets below are held in
// properties rather than written as children -- otherwise the whole config
// fails with "Cannot assign to non-existent default property" (measured, and
// the same reason services/BrightnessMonitor.qml holds its Process and Timer
// that way).

import QtQuick

QtObject {
    id: root

    // The one capability this file needs from outside: file a toast.
    //
    // Assigned at the instantiation site in Notifications.qml. The watchers
    // cannot reach NotificationState themselves, so without this they would
    // have to be written as one big Connections block in the singleton, which is
    // the coupling this split exists to remove.
    //
    // A `required` property may not carry an initializer ("Required
    // properties with initializer do not make sense") and may not be left
    // unassigned ("Required property onAdd was not initialized") -- both
    // measured. Assigned, not redeclared here, which is the shape
    // services/Brightness.qml uses for BrightnessMonitor.
    property var notify: null

    // The single gate for the whole fleet: every handler in both leaves below
    // reaches a toast through one of these calls and nowhere else, so the null
    // check that protects an unwired watcher is written once rather than once
    // per leaf. The leaves call `notify` directly and have no check of their
    // own, which is safe because the two assignments below are part of building
    // this object -- no signal handler runs until the event loop turns.
    function announce(
        summary,
        body,
        appName,
        appIcon,
        urgency,
        actions
    ): void {
        if (!root.notify)
            return

        root.notify(summary, body, appName, appIcon, urgency, actions);
    }

    readonly property NotificationDeviceWatchers devices:
        NotificationDeviceWatchers {
            notify:
                (summary, body, appName, appIcon, urgency, actions) =>
                    root.announce(
                        summary,
                        body,
                        appName,
                        appIcon,
                        urgency,
                        actions
                    )
        }

    readonly property NotificationActivityWatchers activity:
        NotificationActivityWatchers {
            notify:
                (summary, body, appName, appIcon, urgency, actions) =>
                    root.announce(
                        summary,
                        body,
                        appName,
                        appIcon,
                        urgency,
                        actions
                    )
        }
}