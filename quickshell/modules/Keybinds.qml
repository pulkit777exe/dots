pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../services"

Singleton {
    id: root

    IpcHandler {
        target: "shell"
        function toggleControlCenter(): void { UiState.toggleControlCenter(); }
        function toggleSettings(): void { UiState.toggleSettings(); }
        function toggleThemePicker(): void { UiState.toggleThemePicker(); }
        function toggleWallpaperPicker(): void { UiState.toggleWallpaperPicker(); }
        function togglePowerMenu(): void { UiState.togglePowerMenu(); }
        function toggleLauncher(): void { UiState.toggleLauncher(); }
        function toggleClipboard(): void { UiState.toggleClipboard(); }
        function closeAll(): void { UiState.closeAll(); }

        function brightnessUp(): void { Brightness.step(5); }
        function brightnessDown(): void { Brightness.step(-5); }
        function mediaToggle(): void { Media.togglePlay(); }
        function mediaPrev(): void { Media.previous(); }
        function mediaNext(): void { Media.next(); }
        function mediaStop(): void { Media.stop(); }
        function bluetoothToggle(): void { Bluetooth.toggle(); }
        function nightLightToggle(): void { NightLight.toggle(); }
        function clearNotifs(): void { Notifications.clearAll(); }
    }

    IpcHandler {
        target: "auth"
        function show(payload: string): void { Auth.show(payload); }
        function dismiss(cookie: string): void { Auth.dismiss(cookie); }
    }

    IpcHandler {
        target: "uis"
        function isControlCenterOpen(): bool { return UiState.controlCenterOpen; }
        function isSettingsOpen(): bool { return UiState.settingsOpen; }
        function isLauncherOpen(): bool { return UiState.launcherOpen; }
        function isThemePickerOpen(): bool { return UiState.themePickerOpen; }
        function isWallpaperPickerOpen(): bool { return UiState.wallpaperPickerOpen; }
        function isPowerMenuOpen(): bool { return UiState.powerMenuOpen; }
        function isClipboardOpen(): bool { return UiState.clipboardOpen; }
        function isAuthOpen(): bool { return UiState.authOpen; }
    }

    GlobalShortcut { name: "toggleControlCenter"; description: "Toggle control center"; onPressed: UiState.toggleControlCenter() }
    GlobalShortcut { name: "toggleSettings"; description: "Toggle settings app"; onPressed: UiState.toggleSettings() }
    GlobalShortcut { name: "toggleThemePicker"; description: "Toggle theme picker"; onPressed: UiState.toggleThemePicker() }
    GlobalShortcut { name: "toggleWallpaperPicker"; description: "Toggle wallpaper picker"; onPressed: UiState.toggleWallpaperPicker() }
    GlobalShortcut { name: "togglePowerMenu"; description: "Toggle power menu"; onPressed: UiState.togglePowerMenu() }
    GlobalShortcut { name: "toggleLauncher"; description: "Toggle launcher"; onPressed: UiState.toggleLauncher() }
    GlobalShortcut { name: "toggleClipboard"; description: "Toggle clipboard manager"; onPressed: UiState.toggleClipboard() }
    GlobalShortcut { name: "closeAll"; description: "Close all overlays"; onPressed: UiState.closeAll() }

    GlobalShortcut { name: "brightnessUp"; description: "Increase brightness"; onPressed: Brightness.step(5) }
    GlobalShortcut { name: "brightnessDown"; description: "Decrease brightness"; onPressed: Brightness.step(-5) }
    GlobalShortcut { name: "mediaToggle"; description: "Toggle playback"; onPressed: Media.togglePlay() }
    GlobalShortcut { name: "mediaPrev"; description: "Previous track"; onPressed: Media.previous() }
    GlobalShortcut { name: "mediaNext"; description: "Next track"; onPressed: Media.next() }
    GlobalShortcut { name: "mediaStop"; description: "Stop playback"; onPressed: Media.stop() }
    GlobalShortcut { name: "bluetoothToggle"; description: "Toggle Bluetooth"; onPressed: Bluetooth.toggle() }
    GlobalShortcut { name: "nightLightToggle"; description: "Toggle night light"; onPressed: NightLight.toggle() }
    GlobalShortcut { name: "clearNotifs"; description: "Clear notifications"; onPressed: Notifications.clearAll() }
}
