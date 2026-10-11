pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

Singleton {
    id: root

    readonly property var items: SystemTray.items
    readonly property int itemCount: SystemTray.items.values.length
    readonly property bool hasItems: itemCount > 0

    function list(): string {
        const out = [];
        for (const it of SystemTray.items.values) {
            if (it && it.id) out.push(it.id);
        }
        return out.join("\n");
    }

    function count(): int {
        return root.itemCount;
    }

    IpcHandler {
        target: "tray"
        function count(): int { return root.count(); }
        function list(): string { return root.list(); }
    }
}
