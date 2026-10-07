pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// The workspace list the bar's dot indicator draws.
//
// Filter on the name, not `id > 0`: named workspaces have negative ids and
// the obvious filter would silently delete them. `special:*` (scratchpads)
// are overlays, not places you switch to, so they go.

Singleton {
    id: root

    readonly property var items: Hyprland.workspaces.values
        .filter(function (w) { return !w.name.startsWith("special"); })
        .sort(function (a, b) { return a.id - b.id; })

    readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1

    // The workspace's own name: "Desktop" if it was named, "3" if not.
    readonly property string focusedName: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.name : ""

    function focus(ws) {
        if (ws) ws.activate();
    }

    // Slot i on the bar is workspace i+1. An existing workspace activates;
    // a slot with no workspace behind it still switches, and Hyprland
    // creates the numbered workspace on demand.
    function focusIndex(i) {
        const wsId = i + 1;
        const ws = items.find(function (w) { return w.id === wsId; });
        if (ws) focus(ws);
        else Hyprland.dispatch("workspace " + wsId);
    }
}
