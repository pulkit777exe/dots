// The toast list on disk: reading notifs.json back at startup and writing it
// out again whenever the list changes.
//
// One of three files split out of services/Notifications.qml. Not a singleton.
// The other two are NotificationState.qml (the live list) and
// NotificationWatchers.qml (what files a toast).
//
// The direction of the dependency is the whole point. This file depends on
// NotificationState -- it reshapes its list and sets its `loaded` flag -- and
// NotificationState does NOT depend on this one: it cannot reach across, so
// the "something changed, save" nudge travels out through Notifications.qml as
// the `requestSave` callback rather than from state to here.
//
// A QtObject has no default property, so the FileView and the Timer are held
// in properties rather than written as children -- otherwise the whole config
// fails with "Cannot assign to non-existent default property" (measured, and
// the same reason services/BrightnessMonitor.qml holds its Process and Timer
// that way).

import QtQuick
import Quickshell
import Quickshell.Io
// `NotificationUrgency` is provided by Quickshell.Services.Notifications, not by
// Quickshell. Without this the `??` fallback on the urgency read throws a
// ReferenceError inside the parse `try`, so ONE saved toast that lacks the key
// -- and watcher toasts are filed without one, because JSON.stringify drops
// undefined -- took the entire notification history with it on every restart.
import Quickshell.Services.Notifications

QtObject {
    id: root

    // NotificationState. Assigned at the instantiation site in
    // Notifications.qml. `var` because a QML type cannot be named here
    // without this file importing the singleton it lives in, which would be a
    // cycle: Notifications.qml is what declares this type.
    property var store: null

    function reloadable(): var {
        return root.store;
    }

    readonly property Timer saveTimer: Timer {
        // Debounce. `active` is replaced once per filed or dismissed toast, and
        // dismissing four toasts in a row would otherwise write the file four
        // times.
        interval: 1000

        onTriggered: {
            root.storage.setText(
                JSON.stringify(
                    root.reloadable().notClosed.map(n => ({
                        time: new Date().toISOString(),

                        id: n.id,
                        summary: n.summary,
                        body: n.body,

                        appIcon: n.appIcon,
                        appName: n.appName,

                        image: n.image,

                        expireTimeout:
                            n.expireTimeout ??
                            root.reloadable().defaultExpireTimeout,

                        urgency: n.urgency,
                        actions: n.actions
                    }))
                )
            )
        }
    }

    // Called by NotificationState, through Notifications.qml, whenever `active`
    // changes and the read is already folded in.
    function restartSave(): void {
        root.saveTimer.restart()
    }

    readonly property FileView storage: FileView {
        printErrors: true

        path:
            Quickshell.statePath(
                "notifs.json"
            )

        onLoaded: {
            try {
                const data =
                    JSON.parse(text())

                const state = root.reloadable();

                let list =
                    state.active.slice()

                for (const notif of data) {
                    list.push({
                        id:
                            notif.id ??
                            notif.notificationId ??
                            Math.floor(
                                Math.random() * 1000000
                            ),

                        appName:
                            notif.appName ?? "",

                        appIcon:
                            notif.appIcon ?? "",

                        summary:
                            notif.summary ?? "",

                        body:
                            notif.body ?? "",

                        urgency:
                            notif.urgency ??
                            NotificationUrgency.Normal,

                        actions:
                            notif.actions ?? [],

                        image:
                            notif.image ?? "",

                        // A toast read back off disk is history, never a
                        // popup: `popup` is deliberately absent from the
                        // saved shape, so nothing restores one.
                        popup:
                            false
                    })
                }

                state.active = list
            } catch (e) {
                console.warn(
                    "Notifications: failed to parse state",
                    path,
                    e
                )
            }

            root.reloadable().loaded = true
        }

        onLoadFailed: (err) => {
            console.warn(
                "Notifications: failed to load",
                path,
                err
            )

            root.reloadable().loaded = true

            if (
                err ===
                FileViewError.FileNotFound
            ) {
                Qt.callLater(
                    () => setText("[]")
                )
            }
        }
    }
}
