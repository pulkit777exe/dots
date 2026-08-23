pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../core"

/**
 * Backs BOTH the transient toast (Image 4) and the persistent list in
 * Control Center (Image 2) from the same model -- see ARCHITECTURE.md
 * section 3.1: these must not be two separate stores that can drift.
 *
 * Uses Quickshell's built-in Notifications service rather than hand-rolling
 * a D-Bus server. Confirm the import path matches your installed Quickshell
 * version -- this module has moved/renamed across versions historically.
 */
QtObject {
    id: root

    property var items: []   // [{ id, appName, appIcon, summary, body, timestamp }]
    property var newest: null

    property NotificationServer server: NotificationServer {
        onNotification: (notification) => {
            const entry = {
                id: notification.id,
                appName: notification.appName,
                appIcon: notification.appIcon,
                summary: notification.summary,
                body: notification.body,
                urgency: notification.urgency,
                timestamp: Date.now()
            }
            root.items = [entry].concat(root.items).slice(0, 50)
            root.newest = entry
            // Peace mode suppresses the transient toast, not the persistent
            // list -- notifications still land in Control Center, they just
            // don't interrupt with a popup. This was previously dead code:
            // IslandState.showToast() existed but nothing ever called it.
            if (!PeaceService.dndEnabled) {
                IslandState.showToast("notifToast", Config.notifToastTimeout)
            }
        }
    }

    function clearOne(id) {
        items = items.filter(n => n.id !== id)
    }

    function clearAll() {
        items = []
    }

    // Once the toast has collapsed back to idle, drop the reference so a
    // stale notification doesn't get displayed again if notifToast is ever
    // entered some other way.
    property Connections _stateWatch: Connections {
        target: IslandState
        function onShapeChanged() {
            if (IslandState.shape !== "notifToast") root.newest = null
        }
    }
}
