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
    property real expandedCornerRadius: 31

    property bool statusCircleEnabled: true
    property bool albumArtCircleEnabled: true

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
            albumArtCircleEnabled: root.albumArtCircleEnabled
        }));
    }
}
