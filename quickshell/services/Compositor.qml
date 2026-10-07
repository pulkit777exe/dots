pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Compositor state the bar needs: is the focused window fullscreen.
//
// The shape here took several wrong answers, so it is written down:
// there is no `Hyprland.activeWindow` (it reads as undefined, which the old
// shell silently treated as false); `toplevel.activated` is false even for
// the focused window -- it is `wayland.activated` that is true; and
// `wayland.fullscreen` is a plain bool, unlike hyprctl's bitfield.

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
