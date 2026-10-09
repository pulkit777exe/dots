pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property var activeWindow: {
        const rows = Hyprland.toplevels ? (Hyprland.toplevels.values || []) : [];
        for (const t of rows) {
            const w = t.wayland;
            if (w && w.activated) return w;
        }
        return null;
    }

    readonly property bool activeWindowFullscreen:
        activeWindow !== null && activeWindow.fullscreen === true
}
