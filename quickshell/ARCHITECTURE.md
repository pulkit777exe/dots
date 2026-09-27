# Architecture

How this shell is built, why it's built that way, and the complete
reference for its IPC/keybind surface. For "what currently works" see
`README.md`; for "here's every bug that was actually hit and fixed,
in order," see `CHANGELOG.md`.

## Directory structure

```
components/   17 reusable UI primitives (Surface, StyledText, Slider,
               Toggle, ListRow, Icon, ...). Nothing else lives here —
               that's an intentional constraint, kept from this
               project's first design pass.
services/     One Singleton per subsystem (Theme, Wifi, Bluetooth,
               Volume, Brightness, Battery, PowerProfile, Notifications,
               AppLauncher, Auth, NightLight, Iris, Media, Clipboard,
               BarConfig, MotionConfig, UiState). Each wraps a real
               system interface — dbus, a CLI tool, a config file — and
               exposes flat, bindable properties plus an IpcHandler.
surfaces/      The UI layer. Panels/popups built from components,
               reading services, never polling them.
  settings/    Settings-app-specific pages and their own slider style
               (visually distinct from components/Slider.qml, so kept
               out of components/ rather than force-fit into it).
themes/        themes.json (6 presets) + one generated, palette-matched
               wallpaper per theme.
scripts/       Python helpers services shell out to (app indexing,
               polkit agent, wallpaper generation).
shell.qml      Entry point. Creates the PanelWindows, mounts surfaces.
```

## Event-driven, with one honest caveat

Most of `services/` attaches to a real push-based event source — a
D-Bus signal (UPower, NetworkManager, BlueZ), a long-lived monitor
process (`nmcli monitor`, an interactive `bluetoothctl` session), or
`inotifywait` watching a sysfs node (brightness) — and updates its
properties only when something actually changes. Surfaces just bind to
those properties; nothing polls "has anything changed?"

The one place this isn't strictly true: **`inotifywait` is optional**
(see Requirements in `README.md`). Where a service depends on it for
instant file-change notification and it isn't installed, that service
falls back to periodic polling instead. That's a real, different
performance/latency characteristic from the rest of the app, not a
rounding error — worth knowing rather than glossing over.

## Two keybind mechanisms, on purpose

This shell implements every toggle/action two independent ways:

1. **`IpcHandler`** — `qs ipc call <target> <function>`, triggered from
   Hyprland via `bind = ..., exec, qs ipc call ...`. Works on any
   compositor Quickshell runs on; each call spawns a `qs` client
   process that talks to the running instance over its IPC socket.
2. **`CustomShortcut`** — a thin wrapper (`services/CustomShortcut.qml`)
   over Quickshell's `GlobalShortcut` (`Quickshell.Hyprland`), built
   directly on the `hyprland-global-shortcuts-v1` protocol. Hyprland-
   only, but no process-spawn per keypress, and shows up in
   `hyprctl globalshortcuts`.

**They are not redundant in coverage.** Checked directly against
source: `IpcHandler`'s `shell` target exposes 8 functions total, all
four popup toggles plus `closeAll`/`nextTheme`/`nextWallpaper`/
`toggleThemePicker`. `CustomShortcut` covers those same four toggles,
**plus nine actions — brightness up/down, all four media transport
controls, Bluetooth toggle, Night Light toggle, clear-notifications —
that have no `IpcHandler` equivalent at all.** Those nine are only
reachable via the `global` dispatcher syntax. Every `CustomShortcut` in
this codebase left `appid` at its default (`"quickshell"`), so the full
identifier for binding any of them is always `quickshell:<name>`.

**One real, confirmed Hyprland bug to route around**: `binde` (the
repeat-while-held bind variant) combined with `global` triggers an
indefinite repeat that doesn't stop until something else is pressed or
clicked — [hyprwm/Hyprland#8904](https://github.com/hyprwm/Hyprland/issues/8904)
confirms it's most noticeable on exactly the single-key bindings (no
modifier to release) that media/brightness keys are. This project's
documented binds for those deliberately use plain `bind`, not `binde`.

## Complete IPC reference

Every `qs ipc call <target> <function> [args]` this shell exposes,
extracted directly from source:

| Target | Function | Notes |
|---|---|---|
| `shell` | `toggleLauncher` `toggleControlCenter` `togglePowerMenu` `toggleSettings` `toggleClipboard` `closeAll` `nextTheme` `nextWallpaper` `toggleThemePicker` | |
| `uis` | `isLauncherOpen` `isControlCenterOpen` `isPowerMenuOpen` `isSettingsOpen` `isClipboardOpen` | read-only state queries |
| `theme` | `get` `set <name>` `cycle` `list` `getWallpaper` `cycleWallpaper` `toggleDynamic` | |
| `audio` | `getVolume` `setVolume <0-100>` `toggleMute` `cycleOutput` `getSinks` `getSources` `listStreams` | |
| `brightness` | `get` `getFor <query>` `set <0-100>` `setFor <query> <0-100>` | |
| `battery` | `getStatus` `getPercentage` `isCharging` | read-only |
| `bluetooth` | `toggle` `scan` `refresh` `connect <mac>` `disconnect <mac>` `list` `isEnabled` | |
| `wifi` | `status` `toggle` `scan` `connect <ssid> <password>` `disconnect` `getEthernet` `forget <ssid>` | `connect` genuinely forwards a real password || `network` | `status` `toggle` | shorter alias, same underlying Wifi service |
| `nightlight` | `isEnabled` `toggle` `enable` `disable` `setTemp <kelvin>` | |
| `mpris` | `getActive <prop>` `list` `play` `pause` `playPause` `previous` `next` `stop` `toggle` | |
| `powerprofile` | `get` `set <profile>` `cycle` `list` `isAvailable` | |
| `power` | `get` `cycle` | shorter alias, same underlying PowerProfile service |
| `notifs` | `clear` `isDndEnabled` `toggleDnd` `enableDnd` `disableDnd` `list` | |
| `notifications` | `clear` `toggleDnd` | shorter alias — a *subset*, not identical to `notifs` |
| `clipboard` | `list` `refresh` `copy <id>` `del <id>` `wipe` `isAvailable` | `del`, not `delete` — reserved word in JS |

A recurring bug class worth knowing about if you're extending this:
several functions above exist **only** inside an `IpcHandler` block —
they are not callable as `Service.functionName()` from other QML files,
only via `qs ipc call`. `Notifications.toggleDnd()` looked callable
from QML and wasn't; the actual `dnd` property is a plain writable
`property alias`, so surfaces toggle that directly instead. Verified
now by a scripted cross-check (in `CHANGELOG.md`'s "Seventh round")
across every `Service.member` reference in the whole tree, both
directions — nothing else has this problem currently, but it's exactly
the kind of thing that's easy to reintroduce by copy-pasting a pattern
that looks right.

## Windowing and click-masking

`shell.qml` creates two kinds of `PanelWindow`:
- **`barWindow`** — top strip, fixed `exclusiveZone` (pinned to the
  bar's *resting* height, deliberately not its live/hover-expanded
  height — see `CHANGELOG.md` for why that distinction matters).
- **`overlayWindow`** — full-screen, `exclusiveZone: 0`, layer
  `"overlay"`. Hosts every popup (Control Center, Launcher, Power
  Menu, Settings, Clipboard History, notifications, OSD, the auth
  overlay).

Both use `mask: Region { ... }` to make the window click-through except
where something is actually visible — a `Region` per popup, unioned
together, each one conditionally included via `item: condition ?
wrapItem : null`. `Region`'s real, documented properties are `x, y,
width, height, item, shape, intersection` — no `enabled` property
exists. `item: null` is what actually does the "exclude this one"
job, by falling back to the region's zero-default geometry.

**Every wrapped surface needs a real `implicitHeight`** — each wrap
`Item` in `shell.qml` binds its own height (and therefore its `Region`'s
click-mask area) to `<surface>.implicitHeight`. Miss that on a new
surface and it renders perfectly and is entirely unclickable — this
has happened once already (`PowerMenu.qml`, caught before shipping) and
is worth checking explicitly any time a new popup is added.

## Two things that need on-machine validation

Neither of these can be verified without actually running the shell —
noted here rather than silently assumed correct:

- **`scripts/polkit-agent.py`** — registers as a real
  `org.freedesktop.PolicyKit1.AuthenticationAgent`. D-Bus method
  signatures were checked against the actual freedesktop polkit spec
  (correct), and two real logic bugs were found and fixed by reading
  the code closely (a no-helper-found path that never told polkitd the
  auth attempt was over, and an unguarded `subprocess.wait(timeout=5)`
  that could kill the auth thread mid-flow) — but PAM/D-Bus runtime
  behavior itself has never been exercised on a live system.
- **`Region`-based click-masking in `shell.qml`** — structurally
  correct per Quickshell's docs, and the specific `Bar.qml` click bug
  from earlier development was addressed by switching to `MouseArea`
  (matching Quickshell's own official bar tutorial) plus fixing a
  separate, confirmed dead-zone problem — but the *exact* root cause of
  that original click bug was never fully pinned down through static
  analysis alone. If clicks on any popup ever stop registering while
  hover still works, that's the first place to look.

## Version sensitivity — three real examples, not hypothetical

Three separate crashes during development turned out to be Quickshell
API/module differences across versions, not logic bugs:
1. `Qt5Compat.GraphicalEffects` — not installed on the target machine.
   No longer used anywhere in this codebase; every mask (`Surface.qml`'s
   shadow, `Island.qml`'s circular dot, `MediaPlayerSurface.qml`'s
   rounded album art) is done with plain `Rectangle { clip: true }` or
   stacked shapes instead of a real effect.
2. `Region.enabled` — never existed; a fabricated API on my part,
   fixed to the `item: cond ? x : null` pattern described above.
3. `Quickshell.shellDir` — real and current, but Quickshell's own
   changelog shows it was *renamed* from `Quickshell.shellRoot`. If
   wallpaper/theme paths fail to resolve, check which name your
   installed version actually expects.
