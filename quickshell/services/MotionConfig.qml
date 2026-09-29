pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
  MotionConfig service.

  Live, persisted animation settings — the sliders on the Settings app's
  "Motion" page. Consumed across the whole app: Island.qml (shape morph,
  content crossfade, pill hover reveal, punch/settle bounce feedback),
  ControlCenter.qml (page-switch resize), OSD.qml (show/hide),
  PowerMenu.qml (press/confirm), Slider.qml/ListRow.qml/
  SettingsSliderRow.qml (press/fill/stagger), Launcher.qml and
  ClipboardHistory.qml (open pop-in), ThemePicker.qml and
  WallpaperPicker.qml (hover fades), PagePanel.qml and SettingsApp.qml
  (page-switch fades, drag-handle opacity, resize), WifiSettings.qml and
  AudioSettings.qml (toggle hover), Theme.qml (theme-switch color lerp,
  wallpaper crossfade), and shell.qml itself (dim scrim, picker-modal
  pop-in, wallpaper fallback fade), plus the shared base components
  (IconButton, Icon, StyledRect, StyledButton, SearchField, Toggle)
  those surfaces are built from.

  As of this pass, every Behavior/Animation block in the app reads its
  duration from here (or explicitly opts out for a documented reason —
  there are none of those currently), via `fade()`/`hover()`/`movement()`
  for plain-duration NumberAnimation/ColorAnimation, or `springDamping`
  for SpringAnimation-driven size/position changes (Island's shape
  morph, ControlCenter's page resize and slider fills — these have no
  fixed duration to scale, so `movementMs` doesn't apply to them; the
  spring's `bouncePercent`-derived damping is their equivalent control).
  `Theme.animationDuration`, a second fixed-160ms duration constant that
  several of the sites above used to read instead of this file, has
  been removed; if you're tempted to add a new hardcoded duration
  anywhere, that's the bug pattern this cleanup fixed — reach for
  MotionConfig instead.

  `reduceMotion`, when on, is meant to collapse everything to near-
  instant — consumers should treat it as an override, not just another
  duration value, since its whole point is "skip the animation
  entirely" for accessibility/performance, not "make it 1ms".
*/

Singleton {
    id: root

    property bool reduceMotion: false
    property real movementMs: 400      // size/position changes — Bar resize, etc.
    property real fadeMs: 200          // opacity/color transitions
    property real hoverMs: 150         // hover-triggered feedback
    property real slideInMs: 260        // panels sliding down into place
    property real bouncePercent: 40    // spring overshoot amount, 0-100

    // Spring "damping" is what actually controls overshoot in QtQuick's
    // SpringAnimation (lower damping = more bounce) — bouncePercent
    // (0-100, matching the slider in the reference UI) maps onto that
    // inverted range. mass/spring stay fixed; only damping is derived,
    // which is enough range to go from "no bounce" to "quite bouncy"
    // without the four independent numbers a raw spring config would need.
    readonly property real springDamping: root.reduceMotion ? 1.0
        : Math.max(0.25, 0.7 - (root.bouncePercent / 100) * 0.4)

    function setReduceMotion(v) { reduceMotion = v; _persist(); }
    function setMovementMs(v) { movementMs = v; _persist(); }
    function setFadeMs(v) { fadeMs = v; _persist(); }
    function setHoverMs(v) { hoverMs = v; _persist(); }
    function setBouncePercent(v) { bouncePercent = v; _persist(); }

    // The one place "should this animate at all" is decided. Every
    // Behavior/Animation duration in the app calls one of these instead
    // of repeating `reduceMotion ? 0 : fadeMs` inline — so the
    // accessibility override lives in exactly one place, not in dozens
    // of copies of the same ternary scattered across the codebase.
    // `scale` lets a caller stay proportional to the live setting
    // instead of hand-picking a second fixed constant (e.g. a wallpaper
    // crossfade running 1.6x a plain color fade).
    function fade(scale) { return reduceMotion ? 0 : fadeMs * (scale || 1); }
    function hover(scale) { return reduceMotion ? 0 : hoverMs * (scale || 1); }
    // `movementMs` — the size/position slider on the Motion settings
    // page — used to be pure config: nothing actually read it, because
    // every size/position change elsewhere (Island's shape morph,
    // ControlCenter's page resize, slider fills) is SpringAnimation-
    // driven off `springDamping`/`bouncePercent` instead, which has no
    // fixed duration to scale. This is for the other kind: the handful
    // of size/position changes that use a plain NumberAnimation with a
    // real duration (a grid cell resizing, a selection box moving) —
    // those should track this slider like fade()/hover() track theirs.
    function movement(scale) { return reduceMotion ? 0 : movementMs * (scale || 1); }

    readonly property string statePath: Quickshell.statePath("motion-config.json")
    property bool _resolved: false

    FileView {
        id: loader
        path: root.statePath
        watchChanges: false
        printErrors: false
        onLoaded: { root._applyState(text()); root._resolved = true; }
        onLoadFailed: (err) => { root._resolved = true; }
    }
    FileView {
        id: writer
        path: root.statePath
        printErrors: false
    }

    function _applyState(jsonText) {
        try {
            const d = JSON.parse(jsonText);
            if (typeof d.reduceMotion === "boolean") root.reduceMotion = d.reduceMotion;
            if (typeof d.movementMs === "number") root.movementMs = d.movementMs;
            if (typeof d.fadeMs === "number") root.fadeMs = d.fadeMs;
            if (typeof d.hoverMs === "number") root.hoverMs = d.hoverMs;
            if (typeof d.bouncePercent === "number") root.bouncePercent = d.bouncePercent;
        } catch (e) {
            // corrupt/empty state file, ignore
        }
    }

    function _persist() {
        writer.setText(JSON.stringify({
            reduceMotion: root.reduceMotion,
            movementMs: root.movementMs,
            fadeMs: root.fadeMs,
            hoverMs: root.hoverMs,
            bouncePercent: root.bouncePercent
        }));
    }
}
