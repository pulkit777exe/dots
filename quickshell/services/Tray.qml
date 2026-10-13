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

    readonly property string adoptScript: Quickshell.shellDir + "/scripts/adopt-tray-items.py"

    // Clients should re-register with a fresh watcher on their own, but
    // several (Proton VPN, various Electron apps) register once at startup
    // and never again. Their item objects stay alive on the session bus,
    // so a few seconds after startup -- once well-behaved apps have had a
    // chance to return by themselves -- re-register anything orphaned on
    // its behalf. The watcher validates owners and skips duplicates.
    function adopt() {
        adopter.command = ["python3", root.adoptScript];
        adopter.running = true;
    }
    Process {
        id: adopter
        stdout: StdioCollector {}
        stderr: StdioCollector { id: adopterErr }
        onExited: (code) => {
            if (code !== 0) console.warn("Tray: adopt-tray-items failed", code, adopterErr.text);
        }
    }
    Timer {
        interval: 5000
        running: true
        onTriggered: root.adopt()
    }

    IpcHandler {
        target: "tray"
        function count(): int { return root.count(); }
        function list(): string { return root.list(); }
        function adopt(): void { root.adopt(); }
    }
}
