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

    // Read off the adapter below, so there is one copy of each value rather
    // than a property plus a separately parsed copy of it. Nothing assigns
    // these directly -- the set*() functions are the only write path, and they
    // go through the adapter so a save cannot miss a field.
    readonly property bool reduceMotion: data.reduceMotion
    readonly property real movementMs: data.movementMs        // size/position changes — Bar resize, etc.
    readonly property real fadeMs: data.fadeMs                // opacity/color transitions
    readonly property real hoverMs: data.hoverMs              // hover-triggered feedback
    readonly property real bouncePercent: data.bouncePercent  // spring overshoot amount, 0-100

    // Not a setting: no slider, and deliberately not in the state file. A
    // named constant so the two dot panels and the control centre's
    // drill-down sheets all slide the same distance.
    readonly property real slideInMs: 260

    // Spring "damping" is what actually controls overshoot in QtQuick's
    // SpringAnimation (lower damping = more bounce) — bouncePercent
    // (0-100, matching the slider in the reference UI) maps onto that
    // inverted range. mass/spring stay fixed; only damping is derived,
    // which is enough range to go from "no bounce" to "quite bouncy"
    // without the four independent numbers a raw spring config would need.
    readonly property real springDamping: root.reduceMotion ? 1.0
        : Math.max(0.25, 0.7 - (root.bouncePercent / 100) * 0.4)

    function setReduceMotion(v) { data.reduceMotion = v; save(); }
    function setMovementMs(v) { data.movementMs = v; save(); }
    function setFadeMs(v) { data.fadeMs = v; save(); }
    function setHoverMs(v) { data.hoverMs = v; save(); }
    function setBouncePercent(v) { data.bouncePercent = v; save(); }

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

    function save() {
        // Writing before the load resolves would save the declared defaults
        // straight over the saved config: the file arrives asynchronously, so a
        // setter called during startup would otherwise get there first. This
        // file had no such guard.
        if (!root.resolved) return;
        state.writeAdapter();
    }

    // ---- Storage -------------------------------------------------------
    // True once the file has been read, or once we know there isn't one.
    property bool resolved: false


    // One FileView with an adapter on it. The adapter maps each of its
    // properties to a key in the file and does the parsing and the type
    // checking itself, which is why there is no hand-written parse and no
    // `typeof d.x === "number"` guard per field: a missing key leaves the
    // declared default in place, and one of the wrong type is dropped rather
    // than throwing on a corrupt file.
    //
    // Written with an explicit writeAdapter() from save() rather than
    // onAdapterUpdated, because loading the file also updates the adapter's
    // properties, and that would rewrite the file on every start.
    FileView {
        id: state
        path: Quickshell.statePath("motion-config.json")
        // Read once at startup. Watching would fight our own writes.
        watchChanges: false
        printErrors: false
        onLoaded: root.resolved = true
        // No saved config yet is the normal first-run case, not an error.
        onLoadFailed: root.resolved = true

        JsonAdapter {
            id: data
            property bool reduceMotion: false
            property real movementMs: 400
            property real fadeMs: 200
            property real hoverMs: 150
            property real bouncePercent: 40
        }
    }
}
