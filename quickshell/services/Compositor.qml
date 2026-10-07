pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Compositor detection and the one compositor query the bar actually needs.
//
// The plan asked to "isolate Hyprland.* imports behind a shim for future
// niri". Measured, the whole tree had exactly one live reference to the
// Hyprland module -- `Hyprland.activeWindow.fullscreen` in shell.qml, which
// decides whether to hide the island -- plus two imports in Island.qml and
// Keybinds.qml that reference nothing at all.
//
// So the isolation this file provides is real but small: it was the only
// file that imported Quickshell.Hyprland, and shell.qml still does not.
// It is now one of two -- services/Workspaces.qml imports it for the
// workspace indicator -- which is a smaller claim than it used to be, and
// worth not overstating: what this file isolates is compositor DETECTION
// and window state, not the import itself.
//
// What it does NOT do is make the shell portable. `import Quickshell.Hyprland`
// fails to resolve on a compositor that does not ship it, and a QML import
// that does not resolve is a load failure, not a runtime fallback -- so this
// shell still will not start on niri. Porting means replacing this file and
// the three `GlobalShortcut` registrations in Keybinds.qml, not adding
// another indirection. Worth being blunt about, since the point of a shim is
// usually to imply the second thing.
//
// Detection is explicit override -> session type -> assume Hyprland. Assuming
// Hyprland last is deliberate: this is a Hyprland config, install.sh refuses to
// run without hyprland, and the keybinds are Hyprland Lua. Answering "none"
// for an unrecognised session would hide the island and silently break the
// bar, which is a worse failure than being wrong about the name.

Singleton {
    id: root

    // Overridable for testing, and for anyone who knows better.
    property string override: ""

    readonly property string desktop: (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toLowerCase()
    readonly property string sessionType: (Quickshell.env("XDG_SESSION_TYPE") || "").toLowerCase()

    readonly property string compositor: root.override || "hyprland"
    readonly property bool isHyprland: root.compositor === "hyprland"
    // The focused window's Wayland surface, or null.
    //
    // The shape here is not guessable, and establishing it took several wrong
    // answers, so it is written down plainly:
    //
    //   Hyprland.toplevels        a Qt model; its rows are in `.values`
    //   row.wayland               the QtWaylandShellSurface for that toplevel
    //   row.wayland.activated     whether it has focus
    //   row.wayland.fullscreen    whether it is fullscreen
    //
    // There is no `Hyprland.activeWindow`. Reading it yields undefined, and
    // `Boolean(undefined && ...)` is false, so a fullscreen window left the
    // bar sitting on top of it with nothing logged anywhere -- which is what
    // shell.qml had been doing since this feature was written.
    //
    // `activeToplevel` does exist and also stayed null while a window was
    // genuinely focused. And `toplevel.activated` is false even for the
    // focused window -- it is `wayland.activated` that is true. Choosing
    // between those two is the whole difference between working and not.
    //
    // Note that `wayland.fullscreen` is a plain bool, unlike hyprctl's
    // `fullscreen` field, which is a bitfield where 2 means fullscreen is set.
    readonly property var activeWindow: {
        const rows = Hyprland.toplevels ? (Hyprland.toplevels.values || []) : [];
        for (const t of rows) {
            const w = t.wayland;
            if (w && w.activated)
                return w;
        }
        return null;
    }

    // Whether the active window is fullscreen. The island hides itself when
    // it is, so it does not overlap what is playing.

    readonly property bool activeWindowFullscreen:
        activeWindow !== null && activeWindow.fullscreen === true

}
