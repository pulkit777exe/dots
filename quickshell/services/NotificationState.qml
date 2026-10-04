// The toast list and everything that mutates it: the D-Bus ingest path, the
// `qs ipc call notify` path, expiry, the action invoker, and dismissal.
//
// One of three files split out of services/Notifications.qml. That file stays
// the singleton the rest of the tree imports and keeps the public surface;
// this one is not a singleton and has no qmldir `singleton` line.
//
// BOTH ingest paths stay in this file, on purpose. They build equivalent
// entries and they disagree about how long a toast should live -- the client's
// own `expireTimeout` wins on the D-Bus path, urgency wins over the default on
// the other -- and the comments on fallbackExpireTimeout() and on onNotification
// below are the record of why those two rules are opposites. They are one file
// apart on purpose; splitting them further would put them two files apart with
// nothing in between to say so.
//
// What did move out is everything about a toast's lifetime that is not about
// the list: whether it may pop up, the notify sound, the expiry Timer and the
// three budgets. That is NotificationToastLifecycle.qml below, which is handed
// three questions and one callback and owns no list.
//
// The NotificationServer lives HERE rather than in the singleton, which is the
// one place this split departs from the obvious shape: it files toasts, so it
// belongs beside the list it fills and would have to be handed the list, the
// policy, the sound and the budgets to live anywhere else. The two lookups that
// read it need none of that, so they are the part that moved -- to
// NotificationServerHandles.qml below, which takes the server as its one
// argument. Keeping the server beside the list also removes four forward calls
// in `onNotification`.
//
// Why the file uses a QtObject root with every object held in a PROPERTY:
// a QtObject has no default property, so `Process { }` written as a child here
// fails the whole config with "Cannot assign to non-existent default
// property" (measured). services/BrightnessMonitor.qml already holds its
// Process and Timer this way, for the same reason. NotificationToastLifecycle
// is a child object like any other and needs a property for that same reason.

import QtQuick
import Quickshell.Services.Notifications

QtObject {
    id: root

    // The toast list, in arrival order. Every writer replaces the whole array
    // rather than mutating it, so a binding on it -- popups, notClosed, the
    // Region click-mask in shell.qml:333 -- re-evaluates exactly once per
    // change instead of per field.
    property var active: []

    // Written from surfaces/ControlCenter.qml:1666 and from the `notifs`
    // IPC target. Notifications.qml owns the PersistentProperties that make
    // it survive a restart and binds the value in here, because the singleton
    // keeps that object in place rather than moving it into this file.
    property bool dnd: false

    // True once NotificationHistory has finished folding notifs.json into
    // `active`, successfully or not. Until then a change to `active` must not
    // schedule a save, or the read would immediately be written back over.
    property bool loaded: false

    // Persisted verbatim, `popup` and all: a toast that was up when the shell
    // died comes back as history rather than as a fresh popup.
    readonly property var notClosed: active

    // What NotificationStack draws. A toast with popup:false is history only.
    readonly property var popups: active.filter(n => n.popup !== false)

    // The three budgets, forwarded from the lifecycle that spends them.
    // Notifications.qml aliases all three onto this object and
    // NotificationHistory.qml reads `defaultExpireTimeout` when it saves, so
    // these stay here as names on the list even though the numbers moved.
    readonly property int defaultExpireTimeout: toast.defaultExpireTimeout
    readonly property int fullscreenExpireTimeout: toast.fullscreenExpireTimeout
    readonly property int urgentExpireTimeout: toast.urgentExpireTimeout

    // The one thing this file needs from outside. NotificationHistory owns the
    // disk, so the nudge to write goes back out through Notifications.qml
    // rather than from here to there: history depends on this object, and this
    // object must not depend on history.
    //
    // Assigned at the instantiation site in Notifications.qml and nowhere else.
    // A `required` property may not carry an initializer ("Required properties
    // with initializer do not make sense") and may not be left unassigned
    // ("Required property onAdd was not initialized") -- both measured.
    property var requestSave: null

    onActiveChanged: {
        if (root.loaded && root.requestSave)
            root.requestSave();
    }

    // Popup policy, the notify sound and the expiry Timer, with the three
    // budgets above. One object because it is one question -- what happens to a
    // toast while it is up -- and the only thing it has to name is the list,
    // as the `dismissToast` call below.
    readonly property NotificationToastLifecycle toast:
        NotificationToastLifecycle {
            dnd: root.dnd

            dismissToast: (id) => root.dismiss(id)
        }

    // The D-Bus handle vocabulary. trackedHandle() and resolveAction() are pure
    // lookups against the server below, so they are held apart from the two
    // functions that call them -- dismiss() and invokeAction() -- which mutate
    // the list and have to stay with it.
    readonly property NotificationServerHandles handles:
        NotificationServerHandles {
            server: root.server
        }

    // ------------------------------------------------------------------
    // dismissing and invoking

    function dismiss(id: int): void {
        const idx =
            root.active.findIndex(
                n => n.id === id
            )

        if (idx === -1)
            return

        let list =
            root.active.slice()

        list.splice(idx, 1)

        root.active = list

        // Nothing else closes the notification on the client side; leaving the
        // handle alive would strand it in `trackedNotifications` until the
        // sender timed it out.
        const handle = root.handles.trackedHandle(id);

        if (handle)
            handle.dismiss()
    }

    // An invoked action must take its toast down with it whichever way the
    // invoke went. That is why the dismiss lives in a `finally` and not after
    // the call: an action id this notification no longer has, and an invoke()
    // that throws, must both still take the toast off screen.
    //
    // It is also the only thing that can. invoke() closes the notification on
    // the client side but never touches `active`, which is the list the toast
    // is drawn from, so the toast needs dismissing in both the resident and
    // the non-resident case.
    //
    // This is not a double dismiss: when `resident` is false,
    // `NotificationAction::invoke` has already run
    // `NotificationServer::deleteNotification`, which removes the handle from
    // `trackedNotifications`, so the lookup inside dismiss() finds nothing
    // and sends no second close. When `resident` is true, invoke() leaves the
    // handle in place and this is the close.
    function invokeAction(
        id: int,
        actionId: string
    ): void {
        // `actionId` arrives from `qs ipc call` and from a UI click, so it
        // is validated once here rather than trusted as a lookup key.
        if (typeof actionId !== "string" || actionId === "") {
            console.warn(
                "Notifications: invokeAction given an invalid action id",
                id, actionId
            )
            root.dismiss(id)
            return
        }

        const handle = root.handles.trackedHandle(id);

        try {
            const action =
                root.handles.resolveAction(id, handle, actionId);

            if (action)
                action.invoke();
        } catch (e) {
            // An action that throws must not cost the user the toast.
            console.warn(
                "Notifications: action invoke failed", id, actionId, e
            )
        } finally {
            root.dismiss(id);
        }
    }

    function clearAll(): void {
        for (const n of root.active.slice())
            root.dismiss(n.id)
    }

    // ------------------------------------------------------------------
    // the `qs ipc call notify` and system-watcher ingest path

    // The id a toast is filed under. A D-Bus notification arrives carrying one;
    // an `qs ipc call notify` does not, so one is minted here.
    function notificationId(): int {
        return Math.floor(
            Math.random() * 899999
        ) + 100000;
    }

    // How long a toast lives when the client named no lifetime of its own.
    // Critical gets the urgent budget, everything else the normal one.
    //
    // Deliberately NOT the NotificationServer path's own three-way choice
    // below: that one honours `Notification.expireTimeout` when the client set
    // it, adds a fullscreen case, and would have to agree about the 0.3.1
    // docs calling that field seconds when it is milliseconds. Two rules, not
    // one -- so they are not merged here.
    function fallbackExpireTimeout(urgency): int {
        return urgency === NotificationUrgency.Critical
            ? toast.urgentExpireTimeout
            : toast.defaultExpireTimeout;
    }

    // The record every toast is drawn from. Ten fields, and building one is a
    // different job from filing one, so notify() below reads as lifecycle.
    //
    // Only this path substitutes appName/appIcon. The NotificationServer path
    // builds the same ten fields with its own `|| ""` defaults and maps each
    // NotificationAction to {id,label} before it gets here, so the two
    // builders are NOT merged: sharing one would hand every D-Bus notification
    // this path's "System" and "notifications" substitutions.
    function makeEntry(summary, body, appName, appIcon, urgency, actions): var {
        return {
            id: root.notificationId(),

            appName: appName || "System",

            appIcon: appIcon || "notifications",

            summary: summary || "",

            body: body || "",

            urgency:
                urgency !== undefined
                    ? urgency
                    : NotificationUrgency.Normal,

            actions: actions || [],

            image: "",

            popup: toast.shouldShowPopup(),

            expireTimeout: root.fallbackExpireTimeout(urgency)
        };
    }

    function notify(
        summary,
        body,
        appName,
        appIcon,
        urgency,
        actions
    ) {
        const entry =
            root.makeEntry(summary, body, appName, appIcon, urgency, actions);

        let list = root.active.slice();

        list.push(entry);

        root.active = list;

        if (entry.popup) {
            toast.playNotifySound();
        }

        toast.startExpiry(entry.id, entry.expireTimeout);

        return entry.id;
    }

    // ------------------------------------------------------------------
    // the D-Bus ingest path

    readonly property NotificationServer server: NotificationServer {
        keepOnReload: false

        bodySupported: true
        bodyMarkupSupported: true

        actionsSupported: true

        imageSupported: true
        persistenceSupported: true

        bodyHyperlinksSupported: true
        bodyImagesSupported: true

        onNotification: (notification) => {
            const shouldPopup =
                toast.shouldShowPopup()

            const entry = {
                id: notification.id,

                appName:
                    notification.appName || "",

                appIcon:
                    notification.appIcon || "",

                summary:
                    notification.summary || "",

                body:
                    notification.body || "",

                urgency:
                    notification.urgency,

                actions:
                    (notification.actions || [])
                        .map(a => ({
                            id: a.identifier,
                            label: a.text
                        })),

                image:
                    notification.image || "",

                popup:
                    shouldPopup,

                expireTimeout:
                    notification.expireTimeout
            }

            let list =
                root.active.slice()

            list.push(entry)

            root.active = list

            if (shouldPopup) toast.playNotifySound()

            const isCritical =
                notification.urgency ===
                NotificationUrgency.Critical

            // The 0.3.1 docs call `Notification.expireTimeout` a time in
            // seconds. It is milliseconds. `NotificationServer::Notify` takes
            // the raw D-Bus int32 and `Notification::updateProperties` stores
            // it with no conversion anywhere (quickshell v0.3.1,
            // src/services/notifications/server.cpp and notification.cpp), so
            // this value already arrives in the unit `Timer.interval` wants.
            // Dividing by 1000 to agree with the docs would make every toast
            // live 1000x too long.
            const timeoutMs =
                notification.expireTimeout > 0
                    ? notification.expireTimeout
                    : (
                        isCritical
                            ? toast.urgentExpireTimeout
                            : (
                                toast.hasFullscreen()
                                    ? toast.fullscreenExpireTimeout
                                    : toast.defaultExpireTimeout
                            )
                    )

            // The client's own lifetime wins here, where urgency wins in
            // notify(). Those two rules are opposite on purpose and must not
            // be unified: merging them would silently retime every toast that
            // arrives over D-Bus.
            toast.startExpiry(entry.id, timeoutMs)

            notification.tracked = true
        }
    }
}