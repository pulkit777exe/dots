pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
  UiState service — single source of truth for UI mode.

  Enforces one invariant: only one primary mode is active at a time.
  Boolean properties (launcherOpen, etc.) are derived from `mode` for
  backward compatibility. New code should use `mode` directly.

  Surfaces don't reach into each other directly — they read/toggle
  shared state here and react to signals.
*/

Singleton {
    id: root

    // ── Mode enum — single source of truth ──────────────────────────
    enum Mode {
        Closed,
        ControlCenter,
        Launcher,
        Settings,
        Clipboard,
        ThemePicker,
        WallpaperPicker,
        Calendar,
        PowerMenu,
        Media
    }

    property int mode: UiState.Mode.Closed

    // ── Derived boolean compat (backward compatible) ────────────────
    readonly property bool anyOpen: mode !== UiState.Mode.Closed
    readonly property bool launcherOpen: mode === UiState.Mode.Launcher
    readonly property bool controlCenterOpen: mode === UiState.Mode.ControlCenter
    readonly property bool powerMenuOpen: mode === UiState.Mode.PowerMenu
    readonly property bool settingsOpen: mode === UiState.Mode.Settings
    readonly property bool clipboardOpen: mode === UiState.Mode.Clipboard
    readonly property bool themePickerOpen: mode === UiState.Mode.ThemePicker
    readonly property bool wallpaperPickerOpen: mode === UiState.Mode.WallpaperPicker
    readonly property bool calendarOpen: mode === UiState.Mode.Calendar
    readonly property bool mediaOpen: mode === UiState.Mode.Media
    // No lockVisible here any more: the lock screen is hyprlock's, spawned by
    // the Control Center's lock tile, so there is no in-shell lock surface for
    // a visibility flag to describe. The property was declared and never read
    // or written.

    // Which Control Center drill-down is open: "home" | "wifi" | "bluetooth" |
    // "sound" | "display". Lives here rather than only on ControlCenter's own
    // `view` so it can be driven from outside -- by a keybind, or by
    // `quickshell ipc call shell setCcView wifi` when comparing the drill-downs
    // against their references, which is otherwise unreachable without a
    // synthesised pointer.
    property string ccView: "home"

    // ── Calendar: week strip vs month grid ────────────────────────────
    //
    // A sub-state of the calendar rather than a Mode of its own, because both
    // live in the same notch: clicking a day in the strip opens the month grid
    // over it, and the two are never open at once. Making it a Mode would
    // mean the strip had to be re-opened to get back from the month.
    //
    // Reset in closeAll() so reopening the calendar always starts on the strip.
    property bool calendarMonth: false

    // ── Island OSD (volume / brightness) ──────────────────────────────
    //
    // Deliberately NOT a Mode. The OSD is the island's centre notch
    // morphed into the pill, so it has to coexist with whatever is already
    // open (you can drag volume while the calendar is up), and it hides on
    // its own timer rather than on a toggle.
    property bool osdVisible: false
    property string osdKind: "volume"   // "volume" | "brightness"
    property int osdLevel: 0
    property bool osdMuted: false

    function showOsd(kind, level, muted) {
        osdKind = kind;
        osdLevel = level;
        osdMuted = muted === true;
        osdVisible = true;
        osdHideTimer.restart();
    }

    Timer {
        id: osdHideTimer
        interval: ConfigStore.osdOnScreenTimeMs
        onTriggered: root.osdVisible = false
    }


    // ── Mode operations ─────────────────────────────────────────────
    function close() {
        mode = UiState.Mode.Closed;
        calendarMonth = false;
    }

    function toggle(newMode) {
        mode = (mode === newMode) ? UiState.Mode.Closed : newMode;
        // Reopening any mode starts from its default view, so the calendar
        // never comes back on the month grid after a close.
        calendarMonth = false;
    }

    // Clicking a day in the week strip opens the month grid over it.
    function showCalendarMonth() {
        if (mode === UiState.Mode.Calendar) calendarMonth = true;
    }

    // And the month grid's ‹ / › step months; a click on the grid's body (not
    // on an arrow) goes back to the strip.
    function showCalendarWeek() { calendarMonth = false; }

    // ── Named toggles (backward compatible) ─────────────────────────
    function toggleLauncher() { toggle(UiState.Mode.Launcher); }
    function toggleControlCenter() { toggle(UiState.Mode.ControlCenter); }
    function togglePowerMenu() { toggle(UiState.Mode.PowerMenu); }
    function toggleSettings() { toggle(UiState.Mode.Settings); }
    function toggleClipboard() { toggle(UiState.Mode.Clipboard); }
    function toggleThemePicker() { toggle(UiState.Mode.ThemePicker); }
    function toggleWallpaperPicker() { toggle(UiState.Mode.WallpaperPicker); }
    function toggleCalendar() { toggle(UiState.Mode.Calendar); }
    function toggleMedia() { toggle(UiState.Mode.Media); }

    function closeAll() { close(); }
}
