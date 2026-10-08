pragma Singleton

import QtQuick
import Quickshell

// Which overlay, if any, is on screen. One enum: opening one closes the
// rest by construction, and the `*Open` projections below cannot disagree.

Singleton {
    id: root

    enum Mode { Closed, ControlCenter, Settings, ThemePicker, WallpaperPicker, PowerMenu, Launcher, Clipboard }

    property int mode: UiState.Mode.Closed

    // The control centre's own page: "home", "display" or "sound".
    property string ccView: "home"

    // The clipboard manager's own page: the history "list", or the
    // full-size "image" preview Enter opens on an image entry.
    property string clipboardView: "list"

    readonly property bool anyOpen: mode !== UiState.Mode.Closed
    // The bar popups (control centre, pickers, power menu, launcher) share a
    // backdrop and the bar's keyboard grab. The settings app is its own
    // desktop window: no dim, no grab -- it must not trip those triggers.
    readonly property bool popupOpen: anyOpen && !settingsOpen
    readonly property bool controlCenterOpen: mode === UiState.Mode.ControlCenter
    readonly property bool settingsOpen: mode === UiState.Mode.Settings
    readonly property bool themePickerOpen: mode === UiState.Mode.ThemePicker
    readonly property bool wallpaperPickerOpen: mode === UiState.Mode.WallpaperPicker
    readonly property bool powerMenuOpen: mode === UiState.Mode.PowerMenu
    readonly property bool launcherOpen: mode === UiState.Mode.Launcher
    readonly property bool clipboardOpen: mode === UiState.Mode.Clipboard

    function close() {
        mode = UiState.Mode.Closed;
        ccView = "home";
        clipboardView = "list";
    }

    function toggle(newMode) {
        if (newMode === UiState.Mode.Clipboard && mode !== newMode) clipboardView = "list";
        mode = (mode === newMode) ? UiState.Mode.Closed : newMode;
        if (mode !== UiState.Mode.ControlCenter) ccView = "home";
    }

    function closeAll() { close(); }

    function toggleControlCenter() { toggle(UiState.Mode.ControlCenter); }
    function toggleSettings() { toggle(UiState.Mode.Settings); }
    function toggleThemePicker() { toggle(UiState.Mode.ThemePicker); }
    function toggleWallpaperPicker() { toggle(UiState.Mode.WallpaperPicker); }
    function togglePowerMenu() { toggle(UiState.Mode.PowerMenu); }
    function toggleLauncher() { toggle(UiState.Mode.Launcher); }
    function toggleClipboard() { toggle(UiState.Mode.Clipboard); }

    // Escape inside a drill page goes back one level first, then closes.
    function back() {
        if (mode === UiState.Mode.ControlCenter && ccView !== "home") ccView = "home";
        else if (mode === UiState.Mode.Clipboard && clipboardView !== "list") clipboardView = "list";
        else close();
    }
}

