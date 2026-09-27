pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

// Central keybind hub — KISS: one place, explicit types, dual portable path
// IpcHandler (qs ipc call shell <name>) works on any compositor (Sway/Mutter)
// GlobalShortcut (global, quickshell:<name>) is Hyprland-only, zero-fork, low-spec
Singleton {
    id: root

    // UiState toggles — single IpcHandler per target (multiple handlers for same target collide; only last survives)
    IpcHandler {
        target: "shell"
        function toggleLauncher(): void { UiState.toggleLauncher() }
        function toggleControlCenter(): void { UiState.toggleControlCenter() }
        function togglePowerMenu(): void { UiState.togglePowerMenu() }
        function toggleSettings(): void { UiState.toggleSettings() }
        function toggleClipboard(): void { UiState.toggleClipboard() }
        function closeAll(): void { UiState.closeAll() }
        function toggleThemePicker(): void { UiState.toggleThemePicker() }
        function toggleWallpaperPicker(): void { UiState.toggleWallpaperPicker() }
        function toggleCalendar(): void { UiState.toggleCalendar() }
        function toggleMedia(): void { UiState.toggleMedia() }
        // Portability aliases for Hyprland-only actions (also via GlobalShortcut)
        function brightnessUp(): void { Brightness.increaseBrightness() }
        function brightnessDown(): void { Brightness.decreaseBrightness() }
        function mediaToggle(): void { Media.togglePlay() }
        function mediaPrev(): void { Media.previous() }
        function mediaNext(): void { Media.next() }
        function mediaStop(): void { Media.stop() }
        function bluetoothToggle(): void { Bluetooth.toggle() }
        function nightLightToggle(): void { NightLight.toggle() }
        function clearNotifs(): void { Notifications.clearAll() }
    }
    IpcHandler {
        target: "uis"
        function isLauncherOpen(): bool { return UiState.launcherOpen; }
        function isControlCenterOpen(): bool { return UiState.controlCenterOpen; }
        function isPowerMenuOpen(): bool { return UiState.powerMenuOpen; }
        function isSettingsOpen(): bool { return UiState.settingsOpen; }
        function isClipboardOpen(): bool { return UiState.clipboardOpen; }
        function isThemePickerOpen(): bool { return UiState.themePickerOpen; }
        function isWallpaperPickerOpen(): bool { return UiState.wallpaperPickerOpen; }
        function isCalendarOpen(): bool { return UiState.calendarOpen; }
        function isMediaOpen(): bool { return UiState.mediaOpen; }
    }

    GlobalShortcut { name: "toggleLauncher"; description: "Toggle launcher"; onPressed: UiState.toggleLauncher() }
    GlobalShortcut { name: "toggleControlCenter"; description: "Toggle control center"; onPressed: UiState.toggleControlCenter() }
    GlobalShortcut { name: "togglePowerMenu"; description: "Toggle power menu"; onPressed: UiState.togglePowerMenu() }
    GlobalShortcut { name: "toggleSettings"; description: "Toggle settings app"; onPressed: UiState.toggleSettings() }
    GlobalShortcut { name: "toggleClipboard"; description: "Toggle clipboard history"; onPressed: UiState.toggleClipboard() }
    GlobalShortcut { name: "closeAll"; description: "Close all overlays"; onPressed: UiState.closeAll() }
    GlobalShortcut { name: "toggleThemePicker"; description: "Toggle theme picker"; onPressed: UiState.toggleThemePicker() }
    GlobalShortcut { name: "toggleWallpaperPicker"; description: "Toggle wallpaper picker"; onPressed: UiState.toggleWallpaperPicker() }
    GlobalShortcut { name: "toggleCalendar"; description: "Toggle calendar"; onPressed: UiState.toggleCalendar() }
    GlobalShortcut { name: "toggleMedia"; description: "Toggle media card"; onPressed: UiState.toggleMedia() }

    GlobalShortcut { name: "brightnessUp"; description: "Increase brightness"; onPressed: Brightness.increaseBrightness() }
    GlobalShortcut { name: "brightnessDown"; description: "Decrease brightness"; onPressed: Brightness.decreaseBrightness() }
    GlobalShortcut { name: "mediaToggle"; description: "Toggle media playback"; onPressed: Media.togglePlay() }
    GlobalShortcut { name: "mediaPrev"; description: "Previous track"; onPressed: Media.previous() }
    GlobalShortcut { name: "mediaNext"; description: "Next track"; onPressed: Media.next() }
    GlobalShortcut { name: "mediaStop"; description: "Stop media playback"; onPressed: Media.stop() }
    GlobalShortcut { name: "bluetoothToggle"; description: "Toggle Bluetooth"; onPressed: Bluetooth.toggle() }
    GlobalShortcut { name: "nightLightToggle"; description: "Toggle night light"; onPressed: NightLight.toggle() }
    GlobalShortcut { name: "clearNotifs"; description: "Clear all notifications"; onPressed: Notifications.clearAll() }
}
