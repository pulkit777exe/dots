# Architecture

The shell is one Quickshell config rooted at `shell.qml`, rebuilt from the
screenshot set with three layers and nothing else:

- **`components/`** — primitives. `Surface` draws chrome (shadow, border,
  radius), `PopupPanel` is the open/close + focus + Escape contract every
  overlay roots itself in, `Label`/`Icon`/`SearchField`/sliders are the
  vocabulary. No business logic.
- **`services/`** — one singleton per concern, all declared in
  `services/qmldir`. They own state and side effects (D-Bus, `nmcli`,
  `wpctl`, file watches) and expose plain properties/functions; surfaces
  bind to those. `Theme` resolves the palette, `Config` is the only write
  path for settings, `UiState` is one mode enum so exactly one overlay can
  be open.
- **`surfaces/`** — the windows: `Island` (bar), `ControlCenter` (+ `cc/`
  drill pages), `SettingsApp` (+ `settings-app/pages/`), `Launcher`,
  `ThemePicker`, `WallpaperPicker`, `PowerMenu`, `NotificationStack`.
  Surfaces set `width`/`implicitHeight` only; `shell.qml` owns where they
  sit (`anchors.horizontalCenter` + `topY`) and the input mask.
- **`modules/Keybinds.qml`** — the IPC and global-shortcut surface. The
  names are a contract with `hypr/modules/keybinds/quickshell.lua`.

`qmllint` cannot resolve Quickshell's `Singleton`, so the authoritative
check is the running shell's log at `/run/user/$UID/quickshell/by-pid/<pid>/log.log`.

## Complete IPC reference

Generated from `quickshell ipc show`; `tests/run.sh` re-checks this table
against the live shell, so it cannot drift.

| Target | Functions |
| --- | --- |
| `audio` | `getVolume`, `toggleMute`, `setVolume` |
| `auth` | `show`, `dismiss` |
| `brightness` | `set`, `get` |
| `mpris` | `play`, `previous`, `next`, `stop`, `toggle` |
| `nightlight` | `setTemp`, `isEnabled`, `toggle` |
| `notifs` | `clear`, `count`, `dismiss`, `toggleDnd`, `isDndEnabled` |
| `powerprofile` | `set`, `isAvailable`, `get` |
| `shell` | `toggleLauncher`, `mediaPrev`, `mediaNext`, `togglePowerMenu`, `toggleControlCenter`, `mediaStop`, `closeAll`, `mediaToggle`, `brightnessUp`, `toggleThemePicker`, `toggleSettings`, `brightnessDown`, `toggleWallpaperPicker`, `bluetoothToggle`, `nightLightToggle`, `clearNotifs`, `toggleClipboard` |
| `theme` | `set`, `publish`, `cycleWallpaper`, `list`, `cycle`, `getWallpaper`, `get` |
| `tray` | `count`, `list`, `adopt` |
| `uis` | `isPowerMenuOpen`, `isThemePickerOpen`, `isSettingsOpen`, `isLauncherOpen`, `isControlCenterOpen`, `isWallpaperPickerOpen`, `isClipboardOpen`, `isAuthOpen` |
| `wifi` | `connect`, `status`, `disconnect`, `toggle`, `scan` |

A recurring bug class worth knowing
-----------------------------------

A function declared *inside* an `IpcHandler` is reachable over
`quickshell ipc call` but is not a method on the singleton, so `Foo.bar()`
from QML compiles, does nothing, and logs nothing. `scripts/ipc-audit.py`
(run by `scripts/lint.sh`) scans for exactly that: any `Service.member`
reference from QML that resolves only at IpcHandler depth. Keep singletons
as the real API and the handlers as a thin forwarding layer.
