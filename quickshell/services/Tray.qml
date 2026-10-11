pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

Singleton {
    id: root

    readonly property var items: SystemTray.items

    // ObjectModel.values does not notify on insert/remove in a way a
    // `.length` binding can observe (verified: the binding never updates),
    // so track the count from the model's own signals instead. The Repeater
    // in TrayStrip binds the model directly and is unaffected.
    property int itemCount: 0
    readonly property bool hasItems: itemCount > 0

    Connections {
        target: SystemTray.items
        function onObjectInsertedPost() { root.itemCount += 1; }
        function onObjectRemovedPost() { root.itemCount -= 1; }
    }

    Component.onCompleted: itemCount = SystemTray.items.values.length

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
