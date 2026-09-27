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
    property bool lockVisible: false

    property rect islandRect: Qt.rect(0, 0, 0, 0)

    // ── Mode operations ─────────────────────────────────────────────
    function close() {
        mode = UiState.Mode.Closed;
    }

    function toggle(newMode) {
        mode = (mode === newMode) ? UiState.Mode.Closed : newMode;
    }

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
