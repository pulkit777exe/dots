// The two lookups that turn an id from the toast list into the objects a D-Bus
// notification is made of: the NotificationServer's handle for that id, and the
// action a button name names on that handle.
//
// One of the files NotificationState.qml is split into. Not a singleton.
//
// Why these two are here and the server itself is not: the server files toasts,
// so it belongs beside the list it fills, and moving it out would mean handing
// it the list, the popup policy, the sound, the expiry and the three budgets.
// Neither lookup does any of that. Both read the server's handle map and answer
// a name, so all they need is the server -- one line of wiring rather than
// seven.
//
// invokeAction() stays in NotificationState.qml and that is not an oversight:
// it is the only thing that can take a toast down after an invoke, because the
// `finally` is in it. See the comment on it there.

import QtQuick

QtObject {
    id: root

    // NotificationState's NotificationServer. Bound rather than copied at the
    // instantiation site, so the handle map is read from the server that is
    // actually there rather than from whatever existed when this was built.
    property var server: null

    // The NotificationServer's handle for `id`, or undefined.
    //
    // dismiss() and invokeAction() both need one and both need the same
    // `?? []`: the map is only populated once the server has registered a
    // notification, so before the first one it is null rather than empty, and
    // `Array.from(null)` throws.
    function trackedHandle(id: int): var {
        return Array.from(
            root.server?.trackedNotifications?.values ?? []
        ).find(
            n => n.id === id
        );
    }

    // The action `actionId` names on `handle`, or undefined.
    //
    // Returns rather than throws so that invokeAction() still reaches its
    // `finally` and takes the toast down either way; that is the whole reason
    // this is separate from the invoke.
    //
    // The invoke is on the ACTION object, not the notification. `Notification`
    // has no invokeAction() -- it exposes dismiss(), expire() and
    // sendInlineReply() only, and calling a member that does not exist throws.
    // The actions live in `Notification.actions` (list<NotificationAction>)
    // and the call is `NotificationAction.invoke()`; see the 0.3.1 docs for
    // Quickshell.Services.Notifications.
    function resolveAction(id: int, handle, actionId): var {
        const action =
            (handle?.actions ?? []).find(
                a => a.identifier === actionId
            );

        if (!action && handle) {
            console.warn(
                "Notifications: notification has no such action",
                id, actionId
            );
        }

        return action;
    }
}