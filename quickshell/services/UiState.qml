pragma Singleton

import QtQuick
import Quickshell

// Which overlay, if any, is on screen. One enum: opening one closes the
// rest by construction, and the `*Open` projections below cannot disagree.

Singleton {
    id: root

    enum Mode { Closed, ControlCenter, Settings, ThemePicker, WallpaperPicker, PowerMenu, Launcher }

    property int mode: UiState.Mode.Closed

    // The control centre's own page: "home", "display" or "sound".
    property string ccView: "home"

    readonly property bool anyOpen: mode !== UiState.Mode.Closed
    readonly property bool controlCenterOpen: mode === UiState.Mode.ControlCenter
    readonly property bool settingsOpen: mode === UiState.Mode.Settings
    readonly property bool themePickerOpen: mode === UiState.Mode.ThemePicker
    readonly property bool wallpaperPickerOpen: mode === UiState.Mode.WallpaperPicker
    readonly property bool powerMenuOpen: mode === UiState.Mode.PowerMenu
    readonly property bool launcherOpen: mode === UiState.Mode.Launcher

    function close() {
        mode = UiState.Mode.Closed;
        ccView = "home";
    }

    function toggle(newMode) {
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

    // Escape inside a drill page goes back one level first, then closes.
    function back() {
        if (mode === UiState.Mode.ControlCenter && ccView !== "home") ccView = "home";
        else close();
    }
}
