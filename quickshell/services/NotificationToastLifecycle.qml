// What happens to a toast while it is up: whether it may appear on screen at
// all, the sound it makes, and the Timer that takes it away again.
//
// One of the files NotificationState.qml is split into. Not a singleton, and
// not in the Notifications composition: the list asks this three questions --
// can this one pop up, make a sound, expire after this long -- and this file
// answers them. The only thing it needs from the list is the callback that
// takes a toast down, because that is what the expiry Timer fires.
//
// The three lifetimes live here rather than in NotificationState.qml because
// they are one question asked three ways, and because the NotificationServer's
// own three-way choice further down that file needs all three of them at once
// and has to reach through here for them. They are forwarded back out of
// NotificationState.qml, so `Notifications.defaultExpireTimeout` -- which
// Notifications.qml aliases and NotificationHistory.qml reads when it saves --
// is unchanged by any of this.
//
// What did NOT move: which lifetime applies to a given toast. That stays in
// both ingest paths in NotificationState.qml, which disagree about it on
// purpose. See the comments on fallbackExpireTimeout() and on onNotification.
//
// A QtObject has no default property, so the Process and the Component's Timer
// are held in properties rather than written as children -- otherwise the
// whole config fails with "Cannot assign to non-existent default property"
// (measured, and the same reason services/BrightnessMonitor.qml holds its
// Process and Timer that way).

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    // Do not disturb, bound in by NotificationState.qml, which is handed the
    // value by Notifications.qml because the PersistentProperties that make it
    // survive a restart stay there.
    //
    // Assigned at the instantiation site rather than `required`, which is the
    // shape services/Brightness.qml uses for BrightnessMonitor: `required`
    // may not carry an initializer and may not be left unassigned (both
    // measured, and both recorded on NotificationState.qml's `requestSave`).
    property bool dnd: false

    // NotificationState's dismiss(), handed over rather than reached for. The
    // list is a sibling of this file's root inside it and an id does not cross
    // into another file's component, so the Timer below calls this instead of
    // naming a list it cannot see.
    property var dismissToast: null

    // How long a toast lives when nothing else says. Critical gets the urgent
    // budget in both ingest paths, and the fullscreen figure is one of the
    // three the D-Bus path weighs.
    property int defaultExpireTimeout: ConfigStore.notifPopupTimeoutMs
    property int fullscreenExpireTimeout: 3000
    property int urgentExpireTimeout: ConfigStore.notifUrgentTimeoutMs

    // ------------------------------------------------------------------
    // popup policy

    function hasFullscreen(): bool {
        return false
    }

    function shouldShowPopup(): bool {
        if (root.dnd)
            return false

        try {
            if (
                UiState &&
                (
                    UiState.launcherOpen ||
                    UiState.controlCenterOpen
                )
            ) {
                return false
            }
        } catch (e) {}

        if (hasFullscreen())
            return false

        return true
    }

    // ------------------------------------------------------------------
    // sound

    readonly property Process soundPlayer: Process {
    }

    function playNotifySound(): void {
        if (!ConfigStore.notifSoundEnabled) return
        soundPlayer.command = [
            "bash", "-c",
            "canberra-gtk-play -i message-new-instant 2>/dev/null || " +
            "paplay /usr/share/sounds/freedesktop/stereo/message-new-instant.oga 2>/dev/null"
        ]
        soundPlayer.running = true
    }

    // ------------------------------------------------------------------
    // expiry

    readonly property Component expireTimerComponent: Component {

        Timer {
            property int targetId: -1

            // No interval here on purpose: both createObject() call sites pass
            // one, and the default of 0 would dismiss the toast on the next
            // event-loop tick instead of after its expireTimeout.
            running: true
            repeat: false

            onTriggered: {
                if (root.dismissToast)
                    root.dismissToast(targetId)

                destroy()
            }
        }
    }

    // Arms a toast's expiry. Both places that file a toast entry used to open
    // this Timer with the same seven lines; the NotificationServer path has to
    // pass its own `timeoutMs` rather than the entry's, which is the only
    // reason it takes the two values separately.
    function startExpiry(id: int, timeoutMs: int): void {
        expireTimerComponent.createObject(
            root,
            {
                targetId: id,
                interval: timeoutMs
            }
        );
    }
}