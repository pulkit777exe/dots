pragma Singleton
import QtQuick

/**
 * Peace / Do Not Disturb mode -- purely internal state now, not swaync.
 *
 * The previous version shelled out to swaync-client, but this shell also
 * runs its own Quickshell NotificationServer (see NotificationService.qml)
 * -- only one process can own the org.freedesktop.Notifications D-Bus name
 * at a time, so swaync and Quickshell's own server were fighting over the
 * same seat. Whichever won meant either DND toggling had no effect on real
 * notifications, or the Island's own notification list silently stopped
 * receiving anything. Simplest fix: drop the external dependency entirely.
 * NotificationService reads `dndEnabled` directly and suppresses the toast
 * (not the persistent list) while it's on.
 */
QtObject {
    id: root
    property bool dndEnabled: false

    function toggle() { dndEnabled = !dndEnabled }
}
