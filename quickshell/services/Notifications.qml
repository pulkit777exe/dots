// Notifications -- the singleton the rest of the tree imports, and the
// composition root for the three files it was split into:
//
//   NotificationState.qml     the toast list: D-Bus ingest, `notify`, expiry,
//                             dismissal, action invoke, the notify sound
//   NotificationWatchers.qml  what turns a change in another service into a
//                             toast
//   NotificationHistory.qml   notifs.json, both directions
//
// This file is the seam, not the implementation. It owns exactly four things
// that cannot move:
//
//   * the `Notifications` name itself -- qmldir declares the singleton, and
//     40 references across the tree spell it `Notifications.<member>`
//   * both IpcHandlers, because `qs ipc call` addresses them by target and the
//     documented table is checked against the running shell
//   * the PersistentProperties that make `dnd` survive a restart
//   * the wiring between the three, which is the only place both ends of each
//     dependency are in scope at once
//
// Everything below that is a forwarder. The forwarders are load-bearing, not
// boilerplate: scripts/ipc-audit.py self-tests on ("Notifications", "dismiss")
// and NotificationStack.qml calls Notifications.dismiss() and
// Notifications.invokeAction(), so a name that stops being a real member of
// this object fails the audit and breaks the toast buttons.
//
// The three helpers are plain types, not singletons, and each needs a qmldir
// entry: a same-directory type does NOT resolve from inside a module singleton
// ("Type X is not a type", measured). services/BrightnessMonitor.qml is the
// existing precedent for that shape.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ------------------------------------------------------------------
    // the public surface. Every name here is referenced from outside this
    // file, so every name here has to stay a real member of this object.

    // The toast list, oldest first. Ten references, and shell.qml:333 uses its
    // length as a Region click-mask, so it has to be a plain writable
    // property rather than something only this file can assign.
    property alias active: state.active

    // What NotificationStack draws: the toasts that should be up right now,
    // which is `active` minus the ones read back off disk as history.
    readonly property var popups: state.popups

    readonly property var notClosed: state.notClosed

    // Do not disturb. Seven references including a write at
    // surfaces/ControlCenter.qml:1666, which is the only DND toggle in the
    // tree. This alias and the PersistentProperties it points at are
    // deliberately unmoved: the value is the one thing here that has to
    // outlive a restart, and the reloadable is the one object whose
    // registration is not something to relocate for tidiness.
    property alias dnd: props.dnd

    property alias loaded: state.loaded

    property alias defaultExpireTimeout: state.defaultExpireTimeout
    property alias fullscreenExpireTimeout: state.fullscreenExpireTimeout
    property alias urgentExpireTimeout: state.urgentExpireTimeout

    PersistentProperties {
        id: props

        reloadableId: "notifs"

        property bool dnd: false
    }

    onDndChanged: {
        if (dnd) {
            console.log(
                "Do not disturb enabled — popup notifications disabled"
            )
        } else {
            console.log(
                "Do not disturb disabled — popup notifications enabled"
            )
        }
    }

    // ------------------------------------------------------------------
    // the three pieces

    NotificationState {
        id: state

        // One hop. An alias cannot reach through a grandchild
        // ("Invalid alias target location", measured), so this is a binding
        // rather than an alias onto state.popups.
        dnd: props.dnd

        // Nudge to persist. State owns the list and history owns the disk, and
        // neither can name the other's file, so the callback is injected here.
        // `history` unqualified: an id is a scope name, not a property, so
        // `root.history` is undefined (measured).
        requestSave: () => history.restartSave()
    }

    NotificationWatchers {
        id: watchers

        // One capability, handed over rather than reached for: the watchers
        // turn events into toasts and cannot do anything else to the list.
        notify:
            (summary, body, appName, appIcon, urgency, actions) =>
                state.notify(
                    summary,
                    body,
                    appName,
                    appIcon,
                    urgency,
                    actions
                )
    }

    NotificationHistory {
        id: history

        store: state
    }

    // ------------------------------------------------------------------
    // forwarders. See the note at the top of the file: these are audited.

    function dismiss(id: int): void {
        state.dismiss(id)
    }

    function invokeAction(id: int, actionId: string): void {
        state.invokeAction(id, actionId)
    }

    function clearAll(): void {
        state.clearAll()
    }

    function notify(
        summary,
        body,
        appName,
        appIcon,
        urgency,
        actions
    ) {
        return state.notify(
            summary,
            body,
            appName,
            appIcon,
            urgency,
            actions
        );
    }

    // ------------------------------------------------------------------
    // IPC.
    //
    // Both targets stay here. A function declared inside an IpcHandler is
    // reachable over `qs ipc call` but is NOT a member of the singleton, so
    // these names are deliberately not on the object above; that is the trap
    // scripts/ipc-audit.py exists to catch, and the round trip is described in
    // quickshell/CHANGELOG.md under Notifications.toggleDnd().

    IpcHandler {
        target: "notifs"

        function clear(): void {
            for (
                const n of root.active.slice()
            ) {
                root.dismiss(n.id)
            }
        }

        function isDndEnabled(): bool {
            return root.dnd
        }

        function toggleDnd(): void {
            root.dnd =
                !root.dnd
        }

        function enableDnd(): void {
            root.dnd = true
        }

        function disableDnd(): void {
            root.dnd = false
        }

        function list(): string {
            return root.active
                .map(
                    n =>
                        `${n.appName}: ${n.summary}`
                )
                .join("\n")
        }
    }

    IpcHandler {
        target: "notifications"

        function clear(): void {
            root.clearAll()
        }

        function toggleDnd(): void {
            root.dnd =
                !root.dnd
        }
    }
}
