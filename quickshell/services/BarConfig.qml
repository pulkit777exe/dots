pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
  BarConfig service.

  Live, persisted settings for Bar.qml's shape/size — the sliders shown
  on the Settings app's "Bar & Island" page. Bar.qml reads these
  directly instead of hardcoding its own defaults, so dragging a slider
  here takes effect immediately (these are plain bindable properties,
  Bar.qml's own SpringAnimation Behaviors handle the smooth transition)
  and survives restarts via the same FileView-based persistence pattern
  Theme.qml already uses.
*/

Singleton {
    id: root

    readonly property bool notchMode: data.notchMode
    readonly property real notchFlare: data.notchFlare
    readonly property real barHeight: data.barHeight
    readonly property real collapsedWidth: data.collapsedWidth
    readonly property real expandedHeight: data.expandedHeight
    readonly property real minimumExpandedWidth: data.minimumExpandedWidth
    readonly property real gapFromScreenEdge: data.gapFromScreenEdge

    // Only "Corner radius (expanded)" from the reference design is
    // wired here — the collapsed pill shape (`barHeight / 2`) and the
    // notch-flat-top logic are algorithmic, not a flat number, so
    // there's nothing safe to expose for those without breaking the
    // capsule geometry. This unifies what were three separately
    // hardcoded, inconsistent values (24 / 24 / 26 across the three
    // dot wraps) into one.
    //
    // 27, fitted off the reference panel's top-left corner
    // (2026-09-20_22-27-14.png): with the panel's left edge at x 703 and top
    // at y 53, the edge sits at +17 by y=top+2, +13 by +4, +9 by +8 and +3 by
    // +16. A circle of radius R puts the edge at R - sqrt(2Rd - d^2); R=27
    // predicts 16.8 / 12.9 / 7.8 / 3.9 against those measurements. The old 31
    // is visibly tighter than the reference.
    readonly property real expandedCornerRadius: data.expandedCornerRadius

    readonly property bool statusCircleEnabled: data.statusCircleEnabled
    readonly property bool albumArtCircleEnabled: data.albumArtCircleEnabled

    // ---- The Bar & Island page's three remaining rows -------------------
    // These existed in the reference settings UI with no property behind
    // them, so the rows were either faked or omitted. They are now real.
    //
    // Defaults are the reference's own values (2026-09-20_22-30-18).

    // Insets the collapsed dot's artwork from the dot's edge. 3 reproduces
    // what Island.qml hardcoded as `barHeight - 6`, so nothing moves on
    // first load; the slider just makes the number reachable.
    readonly property real innerPadding: data.innerPadding

    // Corner radius of the *collapsed* dot, clamped to barHeight / 2 so the
    // dot can never turn inside-out. The reference shows 20 against a 33px
    // bar, which is already past the capsule limit (16.5) -- so at its
    // default this is a full capsule, exactly as before.
    readonly property real collapsedCornerRadius: data.collapsedCornerRadius

    // How far the dot lifts on hover, in px, moving up and out of the bar.
    // Island.qml used a fixed 1px nudge *down* instead, which read as a
    // press rather than a lift.
    readonly property real stageLiftOnHover: data.stageLiftOnHover
    // How far a dot panel starts above its resting place and slides down
    // into it. One value for both panels so they move as a pair.
    property real panelSlideIn: 22

    function setNotchMode(v) { data.notchMode = v; save(); }
    function setNotchFlare(v) { data.notchFlare = v; save(); }
    function setBarHeight(v) { data.barHeight = v; save(); }
    function setCollapsedWidth(v) { data.collapsedWidth = v; save(); }
    function setExpandedHeight(v) { data.expandedHeight = v; save(); }
    function setMinimumExpandedWidth(v) { data.minimumExpandedWidth = v; save(); }
    function setGapFromScreenEdge(v) { data.gapFromScreenEdge = v; save(); }
    function setExpandedCornerRadius(v) { data.expandedCornerRadius = v; save(); }
    function setStatusCircleEnabled(v) { data.statusCircleEnabled = v; save(); }
    function setAlbumArtCircleEnabled(v) { data.albumArtCircleEnabled = v; save(); }
    function setInnerPadding(v) { data.innerPadding = v; save(); }
    function setCollapsedCornerRadius(v) { data.collapsedCornerRadius = v; save(); }
    function setStageLiftOnHover(v) { data.stageLiftOnHover = v; save(); }

    // The single clamped radius the Island actually applies. Exposed as a
    // readonly so the three call sites can't each re-derive (and mis-clamp)
    // it.
    readonly property real effectiveCollapsedRadius: Math.min(collapsedCornerRadius, barHeight / 2)

    // ---- Storage -------------------------------------------------------
    // True once the file has been read, or once we know there isn't one.
    property bool resolved: false

    // Writes the adapter out. Guarded on `resolved` because the file loads
    // asynchronously: a setter called during startup would otherwise
    // serialise the defaults straight over the saved config.
    function save() {
        if (!root.resolved) return;
        state.writeAdapter();
    }

    // One FileView with an adapter on it. The adapter maps each of its
    // properties to a key in the file and does the parsing and the type
    // checking itself, so there is no hand-written parse and no
    // `typeof d.x === "number"` guard per field: a missing key leaves the
    // declared default in place, and one of the wrong type is dropped
    // rather than throwing on a corrupt file.
    //
    // Written with an explicit writeAdapter() from save() rather than
    // onAdapterUpdated, because loading the file also updates the adapter's
    // properties, and that would rewrite the file on every start.
    FileView {
        id: state
        path: Quickshell.statePath("bar-config.json")
        // Read once at startup. Watching would fight our own writes.
        watchChanges: false
        printErrors: false
        onLoaded: root.resolved = true
        // No saved config yet is the normal first-run case, not an error.
        onLoadFailed: root.resolved = true

        JsonAdapter {
            id: data
            property bool notchMode: false
            property real notchFlare: 16
            property real barHeight: 33
            property real collapsedWidth: 90
            property real expandedHeight: 125
            property real minimumExpandedWidth: 440
            property real gapFromScreenEdge: 11
            property real expandedCornerRadius: 27
            property bool statusCircleEnabled: true
            property bool albumArtCircleEnabled: true
            property real innerPadding: 3
            property real collapsedCornerRadius: 20
            property real stageLiftOnHover: 7
        }
    }
}
