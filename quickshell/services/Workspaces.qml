pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// The workspace list the bar draws from.
//
// Compositor.qml keeps its remit -- "which compositor, is the focused window
// fullscreen" -- and this is deliberately not a fourth property bolted onto
// it: the workspace list is a different question, it changes at runtime
// rather than once at startup, and the indicator is its only consumer.
//
// It is the second file in the tree to import Quickshell.Hyprland, which
// makes Compositor.qml's "the only file" header a little stale; it is kept
// as two files rather than merged because merging would give a small
// detection shim a live model binding and a click handler.
Singleton {
    id: root

    // Every workspace you actually live in, in id order.
    //
    // The order is the whole point: Hyprland's own list is sorted by id
    // already, but filtering reorders nothing, and the indicator's
    // left-to-right has to match Super+1..9 rather than the order the
    // compositor happened to create them in.
    //
    // Dropped: special workspaces (`special:magic`, the scratchpad), which
    // are overlays that sit on top of a workspace rather than places you
    // switch to. Named workspaces are KEPT -- their ids are negative, so the
    // obvious `id > 0` filter would silently delete them, which is why this
    // filters on the name instead.
    readonly property var items: Hyprland.workspaces.values
        .filter(function (w) { return !w.name.startsWith("special") })
        .sort(function (a, b) { return a.id - b.id })

    readonly property int focusedId: Hyprland.focusedWorkspace
        ? Hyprland.focusedWorkspace.id
        : -1

    // The label the rich island prints above the indicator. It is the
    // workspace's own name, so a named workspace reads "Desktop" and a
    // default one reads "3" -- the bar reports the name, it does not invent
    // one, and naming a workspace in Hyprland is what changes this string.
    readonly property string focusedName: Hyprland.focusedWorkspace
        ? Hyprland.focusedWorkspace.name
        : ""

    // Switch workspace by handing back the model object rather than an id:
    // the delegate already holds it, `activate()` is the documented way to
    // focus a workspace, and going through an id would mean a string
    // round-trip through the dispatcher for no gain.
    function focus(ws) {
        if (ws) ws.activate()
    }
}
