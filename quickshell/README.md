# Hyprland Island -- Quickshell config

Dynamic-island-style UI for Hyprland, built on Quickshell/QML. Implements the
architecture in `ARCHITECTURE.md`: two singletons (`core/Theme.qml` for
colors+metrics, `core/IslandState.qml` for shape+panels) as the single
source of truth, everything else reads from those.

## What actually works vs. what's scaffolded

Being direct about this rather than let the file tree imply more than it
delivers:

**Solid, tested outside QML (bash, verified to actually run):**
- `scripts/island-set-theme.sh` -- validates theme, persists selection,
  regenerates hyprlock's color file. Tested: theme switching, metric
  survival across theme switches, and failure on bad input all verified.
- `scripts/island-set-metric.sh` -- persists bar-height/font-size, never
  touches hyprlock colors. Tested the same way.
- `scripts/apply-wallpaper.sh`, `scripts/list-apps.sh`,
  `scripts/island-dispatch.sh` -- syntax-checked; `list-apps.sh` tested
  against real `.desktop` files.
- All 12 `themes/*.json` -- valid JSON, colors as specified.

**Written against Quickshell's documented API, NOT runtime-verified (no
Wayland compositor in the environment this was built in):**
- Everything under `core/`, `services/`, `components/`, and `shell.qml`.
- Specifically uncertain: `FileView`'s exact read/reload signature,
  `Quickshell.Services.Notifications`' import path (this module has moved
  across Quickshell versions), and the `qs ipc call` CLI spelling in
  `island-dispatch.sh`.
- Run this through your coding agent against your actual installed
  Quickshell version as a first pass -- treat `qs -c shell.qml` errors as
  "which API surface changed" rather than "this is broken."

**Deliberately incomplete, flagged in-place, not hidden:**
- `AudioService` has device enumeration (sink/source parsing from `wpctl status`)
  and `AudioPanel.qml` shows a functional device picker. Volume/mute and
  device switching are wired.
- `list-apps.sh` is a single-pass `.desktop` parser: no locale-aware
  `Name[xx]=`, no icon theme resolution. Fine to ship, flagged as a known
  simplification.
- The polkit agent has a scope note in `polkit-agent/README.md` but no
  implementation -- it's a separate subproject (C++ + polkit-qt6).
- Wallpaper images themselves are not included -- `themes/*.json` references
  filenames under a `wallpapers/` directory you'll need to populate; adjust
  paths if you organize yours differently.

## Layout

```
core/          Theme.qml, IslandState.qml -- the two singletons
themes/        one JSON palette per theme (12 total, 4 Catppuccin flavors)
services/      Network, Bluetooth, Audio, Mpris, Notification -- CLI/D-Bus wrappers
components/    IdlePill, VolumeToast, NotificationToast, ControlCenter,
               Launcher, Settings, ThemePicker, WallpaperPicker, PowerMenu
components/panels/   Wifi, Bluetooth, Audio sub-panels
components/ui/       shared atoms: ToggleRow, Slider01, MediaCard, NotificationRow
scripts/       bash -- theme/metric persistence, wallpaper apply, app list, IPC dispatch
hyprlock/      hyprlock.conf.template consuming the generated color file
config/        hyprland-island.conf -- exec-once + keybinds to source
polkit-agent/  scope note, not an implementation (separate subproject)
```

## Install

```bash
mkdir -p ~/.config/hypr/hypr-island
cp -r . ~/.config/hypr/hypr-island
```

Then in `~/.config/hypr/hyprland.conf`:

```
source = ~/.config/hypr/hypr-island/config/hyprland-island.conf
```

And point your `hypr/hyprlock.conf` at `hyprlock/hyprlock.conf.template`
(copy it in, or `source =` it if your hyprlock version supports that).

Requires: `qs` (Quickshell), `jq`, `nmcli`, `bluetoothctl`, `wpctl`,
`playerctl`, `swaybg`, `hyprlock`.

## Keybinds (confirmed)

| Bind | Action |
|---|---|
| `Super+Space` | toggle Control Center (also the no-mouse fallback for hover-intent) |
| `Alt+Space` | toggle launcher (top-level) |
| `Super+T` | theme picker, direct entry |
| `Super+W` | wallpaper picker, direct entry |
| `Super+S` | settings, direct entry |
| `Super+P` | power menu, direct entry |

Hover-intent (idle pill -> Control Center on hover, ~350ms open delay /
~250ms close delay) is handled in `IslandState.qml` regardless of keybind use.

See `ARCHITECTURE.md` for the full state machine, the four still-open design
questions (Catppuccin flavor handling, e-ink status-color approach, keybind
collision check), and the reasoning behind every "why is it built this way"
decision above.
