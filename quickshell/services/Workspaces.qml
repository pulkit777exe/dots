pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property var items: Hyprland.workspaces.values
        .filter(function (w) { return !w.name.startsWith("special"); })
        .sort(function (a, b) { return a.id - b.id; })

    readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1

    readonly property string focusedName: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.name : ""

    function focus(ws) {
        if (ws) ws.activate();
    }

    function focusIndex(i) {
        const wsId = i + 1;
        const ws = items.find(function (w) { return w.id === wsId; });
        if (ws) focus(ws);
        else Hyprland.dispatch("workspace " + wsId);
    }
}
