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

    property bool notchMode: false
    property real notchFlare: 16
    property real barHeight: 33
    property real collapsedWidth: 90
    property real expandedHeight: 125
    property real minimumExpandedWidth: 440
    property real gapFromScreenEdge: 11

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
    property real expandedCornerRadius: 27

    property bool statusCircleEnabled: true
    property bool albumArtCircleEnabled: true

    // ---- The Bar & Island page's three remaining rows -------------------
    // These existed in the reference settings UI with no property behind
    // them, so the rows were either faked or omitted. They are now real.
    //
    // Defaults are the reference's own values (2026-09-20_22-30-18).

    // Insets the collapsed dot's artwork from the dot's edge. 3 reproduces
    // what Island.qml hardcoded as `barHeight - 6`, so nothing moves on
    // first load; the slider just makes the number reachable.
    property real innerPadding: 3

    // Corner radius of the *collapsed* dot, clamped to barHeight / 2 so the
    // dot can never turn inside-out. The reference shows 20 against a 33px
    // bar, which is already past the capsule limit (16.5) -- so at its
    // default this is a full capsule, exactly as before.
    property real collapsedCornerRadius: 20

    // How far the dot lifts on hover, in px, moving up and out of the bar.
    // Island.qml used a fixed 1px nudge *down* instead, which read as a
    // press rather than a lift.
    property real stageLiftOnHover: 7

    function setNotchMode(v) { notchMode = v; _persist(); }
    function setNotchFlare(v) { notchFlare = v; _persist(); }
    function setBarHeight(v) { barHeight = v; _persist(); }
    function setCollapsedWidth(v) { collapsedWidth = v; _persist(); }
    function setExpandedHeight(v) { expandedHeight = v; _persist(); }
    function setMinimumExpandedWidth(v) { minimumExpandedWidth = v; _persist(); }
    function setGapFromScreenEdge(v) { gapFromScreenEdge = v; _persist(); }
    function setExpandedCornerRadius(v) { expandedCornerRadius = v; _persist(); }
    function setStatusCircleEnabled(v) { statusCircleEnabled = v; _persist(); }
    function setAlbumArtCircleEnabled(v) { albumArtCircleEnabled = v; _persist(); }
    function setInnerPadding(v) { innerPadding = v; _persist(); }
    function setCollapsedCornerRadius(v) { collapsedCornerRadius = v; _persist(); }
    function setStageLiftOnHover(v) { stageLiftOnHover = v; _persist(); }

    // The single clamped radius the Island actually applies. Exposed as a
    // readonly so the three call sites can't each re-derive (and mis-clamp)
    // it.
    readonly property real effectiveCollapsedRadius: Math.min(collapsedCornerRadius, barHeight / 2)

    readonly property string statePath: Quickshell.statePath("bar-config.json")

    property bool _resolved: false

    FileView {
        id: loader
        path: root.statePath
        watchChanges: false
        printErrors: false
        onLoaded: { root._applyState(text()); root._resolved = true; }
        onLoadFailed: (err) => { root._resolved = true; } // no saved config yet, keep defaults
    }

    FileView {
        id: writer
        path: root.statePath
        printErrors: false
    }

    function _applyState(jsonText) {
        try {
            const d = JSON.parse(jsonText);
            if (typeof d.notchMode === "boolean") root.notchMode = d.notchMode;
            if (typeof d.notchFlare === "number") root.notchFlare = d.notchFlare;
            if (typeof d.barHeight === "number") root.barHeight = d.barHeight;
            if (typeof d.collapsedWidth === "number") root.collapsedWidth = d.collapsedWidth;
            if (typeof d.expandedHeight === "number") root.expandedHeight = d.expandedHeight;
            if (typeof d.minimumExpandedWidth === "number") root.minimumExpandedWidth = d.minimumExpandedWidth;
            if (typeof d.gapFromScreenEdge === "number") root.gapFromScreenEdge = d.gapFromScreenEdge;
            if (typeof d.expandedCornerRadius === "number") root.expandedCornerRadius = d.expandedCornerRadius;
            if (typeof d.statusCircleEnabled === "boolean") root.statusCircleEnabled = d.statusCircleEnabled;
            if (typeof d.albumArtCircleEnabled === "boolean") root.albumArtCircleEnabled = d.albumArtCircleEnabled;
            if (typeof d.innerPadding === "number") root.innerPadding = d.innerPadding;
            if (typeof d.collapsedCornerRadius === "number") root.collapsedCornerRadius = d.collapsedCornerRadius;
            if (typeof d.stageLiftOnHover === "number") root.stageLiftOnHover = d.stageLiftOnHover;
        } catch (e) {
            // corrupt/empty state file, ignore — keep defaults
        }
    }

    function _persist() {
        writer.setText(JSON.stringify({
            notchMode: root.notchMode,
            notchFlare: root.notchFlare,
            barHeight: root.barHeight,
            collapsedWidth: root.collapsedWidth,
            expandedHeight: root.expandedHeight,
            minimumExpandedWidth: root.minimumExpandedWidth,
            gapFromScreenEdge: root.gapFromScreenEdge,
            expandedCornerRadius: root.expandedCornerRadius,
            statusCircleEnabled: root.statusCircleEnabled,
            albumArtCircleEnabled: root.albumArtCircleEnabled,
            innerPadding: root.innerPadding,
            collapsedCornerRadius: root.collapsedCornerRadius,
            stageLiftOnHover: root.stageLiftOnHover
        }));
    }
}
