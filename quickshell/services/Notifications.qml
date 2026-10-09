pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    property var history: []
    property var toasts: []

    readonly property bool dnd: Config.dnd

    function toggleDnd() { Config.set("dnd", !Config.dnd); }

    readonly property NotificationServer server: NotificationServer {
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        onNotification: (n) => root.ingest(n)
    }

    function ingest(n) {
        const entry = {
            key: n.id,
            appName: n.appName || "",
            appIcon: n.appIcon || "",
            summary: n.summary || "",
            body: n.body || "",
            urgent: n.urgency === NotificationUrgency.Critical,
            handle: n
        };
        history = [entry].concat(history).slice(0, 100);

        if (!Config.dnd) {
            const timeout = n.expireTimeout > 0
                ? n.expireTimeout
                : (entry.urgent ? Config.notifUrgentTimeoutMs : Config.notifPopupTimeoutMs);
            toasts = toasts.concat([{ key: entry.key, deadline: Date.now() + timeout }]);
        }

        n.tracked = true;
        sweep.restart();
    }

    Timer {
        id: sweep
        interval: 500
        repeat: true
        running: root.toasts.length > 0
        onTriggered: {
            const now = Date.now();
            root.toasts = root.toasts.filter(t => t.deadline > now);
        }
    }

    function entryFor(key) {
        for (const e of history) if (e.key === key) return e;
        return null;
    }

    function dismiss(key) {
        const e = entryFor(key);
        if (e && e.handle) e.handle.dismiss();
        history = history.filter(x => x.key !== key);
        toasts = toasts.filter(t => t.key !== key);
    }

    function clearAll() {
        for (const e of history) if (e.handle) e.handle.dismiss();
        history = [];
        toasts = [];
    }

    IpcHandler {
        target: "notifs"
        function clear(): void { root.clearAll(); }
        function dismiss(key: string): void { root.dismiss(parseInt(key)); }
        function count(): int { return root.history.length; }
        function toggleDnd(): void { root.toggleDnd(); }
        function isDndEnabled(): bool { return root.dnd; }
    }
}
