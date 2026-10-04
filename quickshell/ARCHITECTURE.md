# Architecture

How this shell is built, why it's built that way, and the complete
reference for its IPC/keybind surface. For "what currently works" see
`README.md`; for "here's every bug that was actually hit and fixed,
in order," see `CHANGELOG.md`.

## Directory structure

138 QML files. One rule decides where a new one goes: a **singleton**
(`pragma Singleton` plus a `singleton` line in `services/qmldir`) holds
mutable state that outlives any view of it and there is exactly one of
it; anything else is a plain type, constructed by whatever knows which
one it is about.

```
components/   34 files. The reusable primitives (Surface, StyledText,
               Slider, Toggle, ListRow, Icon, SearchField, Scrim, ...)
               plus two families that are reused rather than general:
               13 Cc*.qml (the control centre's design tokens and its
               controls) and 4 Preview*.qml. The "nothing else lives
               here" constraint was relaxed once, deliberately and
               narrowly — see below.
services/     42 files. 24 singletons: Theme, Wifi, Bluetooth, Volume,
               Brightness, Battery, PowerProfile, PowerManager,
               Notifications, AppLauncher, Auth, Compositor, NightLight,
               Media, Clipboard, Cava, DeviceProfile, ConfigStore,
               IdleInhibit, ControlCenterLayout, ControlCenterGrid,
               BarConfig, MotionConfig, UiState. Each wraps a real
               system interface — dbus, a CLI tool, a config file — and
               exposes flat, bindable properties plus an IpcHandler.
               The other 18 are plain types: collaborators a singleton
               constructs (ColorMath, ColorWatch, ThemeRows,
               WallpaperSetter, ClipboardThumbnails, BacklightDevice,
               BrightnessMonitor, BrightnessMonitors,
               BarConfigMonitors) and the pieces a large service was
               split into (seven Notification*.qml).
  wifi/        The two nmcli halves of Wifi.qml, imported relatively
               (`import "wifi"`). A subdirectory rather than two more
               files beside Wifi.qml because `services/` carries a
               qmldir, and a type a qmldir-bearing directory does not
               list does not resolve.
surfaces/     The UI layer. 60 files: panels and popups built from
               components, reading services, never polling them.
  cc/          The control centre's five pages, one file each. They
               were the body of a 2,255-line ControlCenter.qml, and
               nothing about a Wi-Fi page is shared with anything
               outside the control centre.
  settings/    Settings-app-specific pages and their own slider style
               (visually distinct from components/Slider.qml, so kept
               out of components/ rather than force-fit into it).
               `settings/pages/` holds the page bodies.
themes/        themes.json (6 presets) + one generated, palette-matched
               wallpaper per theme.
scripts/       Python helpers services shell out to (app indexing,
               polkit agent, wallpaper generation, theme discovery,
               palette publishing, lid/suspend state, sysfs watching).
shell.qml      Entry point. Creates the PanelWindows, mounts surfaces.
```

**The `Cc*.qml` exception, stated once so it is not mistaken for
sloppiness.** `components/` has no `qmldir`; it is imported as a
directory, so Quickshell synthesizes one and every type in it resolves
as a sibling. Adding a `qmldir` to declare `CcTokens` a singleton
would change how all 34 of those resolve, so it is a plain `QtObject`
and each file that wants it declares one as a child. That is the reason,
and it is a constraint rather than a preference.

## Colours: static palettes, published outward

`Theme.qml` has no colour generator and no wallpaper sampling. The active
theme's own hand-authored `~/.config/colors/themes/<name>/colors.json` is
the palette, in-shell and on disk alike:

```
colors/themes/<name>/colors.json          (hand-authored, source of truth)
  ├─ scripts/list-themes.py ──────────► Theme.presets ──► in-shell colours
  └─ scripts/publish-colors.py ───────► ~/.config/colors/{current.json,
                                       colors.css, colors.sh, hyprland.conf,
                                       gtk.css, kitty.conf} + live
                                       hyprctl border push
```

`Theme.qml` runs `publish-colors.py <theme>` on startup (once presets and
saved state have both resolved, so the name is final) and again on every
theme switch, so the desktop never lags the shell. Which theme that is:

| Knob | Scope |
|---|---|
| ThemePicker in the island, `qs ipc call theme set <name>`, `nextTheme` keybind | what the shell shows |
| `~/.config/quickshell/shell-state/theme-state.json` (`{"theme": ...}`) | the shell's saved selection — wins over the index when present |
| `current` in `~/.config/colors/index.json` | the active theme used by `list-themes.py` when there's no saved state, and by `publish-colors.py` when run standalone |
| `QUICKSHELL_THEME=gruvbox publish-colors.py` | one-off override, beats `index.json` |

### Colour lives in the theme layer, and nowhere else

**There are no colour literals in this tree outside `services/Theme.qml`.**
Every hex you can grep for in any other `.qml` is inside a comment. That is
checkable and it is the rule, not an accident:

- A colour is `Theme.colors.<key>`, a palette key, or an alpha of one.
- The way to take an alpha is `Theme.withAlpha(Theme.colors.x, a)` — 128 call
  sites across 52 files, counted today. (The `134` quoted in `ColorMath.qml`'s
  and `Theme.qml`'s own comments is stale.)
- The **one** exception is `Theme.fallbackColors`, plus `Theme.panelFill`. Both
  are deliberate: `fallbackColors` is what the shell draws with before
  `list-themes.py` has answered and what `ThemeRows.themeRows()` falls back to
  for a theme missing a key, and `panelFill` is the base every translucent
  surface is composited against — a palette that could set it would be deciding
  how opaque the shell's own panels are.

This was not true until recently. `ControlCenter.qml` declared eleven
`readonly property color` tokens of its own, ten of which matched no palette in
`colors/themes/` at all and one of which matched gruvbox's `background` by
coincidence, and it spelled out 79 more hex literals inline. They are now
`components/CcTokens.qml`: 24 properties, every one a palette key or
`Qt.alpha(paletteKey, a)`, nothing defined that is not derived.

**How much of that is enforced, and how much is only true today.**
`tests/run.sh`'s **theme tokens** section collects every `Theme.colors.<key>`
in the tree and requires it to exist in all six palettes (355 references, 13
distinct keys, 6 palettes) — the bug that shipped once, `Theme.colors.accentAlt`
in `AuthDialog.qml`, which exists in no palette — and separately requires all
six palettes to define the same key set, so a key added to one is caught on
the palette nobody was editing.

The *literal* half is **not** wired into any check. `scripts/lint.sh` has no
colour-literal rule (its grep rules are `qt5compat`, `region-enabled`,
`parent-parent`, `signal-property` and `anchor-vs-explicit`; the
`color-literal*` id that appears in `ALLOW`'s comment is not a rule that
exists). "Zero literals outside `Theme.qml`" is a fact about this commit,
checkable with

```bash
grep -rEn '#[0-9a-fA-F]{3,8}\b' quickshell --include='*.qml' | grep -v services/Theme.qml
```

which returns comments and nothing else. Turning that grep into a lint rule is
the obvious next step and has not been done.

If you add a colour, it goes in `colors/themes/<name>/colors.json` (six files,
18 keys) and in `fallbackColors` if the shell must draw before discovery
answers. Nowhere else.

## Event-driven, with one honest caveat

Most of `services/` attaches to a real push-based event source — a
D-Bus signal (UPower, NetworkManager), a BlueZ object-manager signal
(Bluetooth), a long-lived monitor process (`nmcli monitor`), or
`inotify-watch.py` watching a sysfs node (brightness) — and updates its
properties only when something actually changes. Surfaces just bind to
those properties; nothing polls "has anything changed?"

### What being event-driven was costing, and what it cost to find out

This is the section the caveat below belongs next to, because for a long
while the claim above was true of the *services* and false of the *shell*.
Four loops, found by counting processes rather than by reading code, and
each with the arithmetic it was found by:

| What | Why it was running | After |
|---|---|---|
| `PowerProfile.qml` ran `powerprofilesctl monitor` | `monitor` **is not a subcommand of that tool** — it exits 2 with `invalid choice: 'monitor'` | a `Connections` on `Quickshell.Services.UPower`'s `PowerProfiles` singleton, which already mirrors `org.freedesktop.UPower.PowerProfiles.ActiveProfile` and emits `profileChanged`. **19 spawns/min → 0** |
| `Wifi.qml` ran an unconditional 5s `nmcli` poll | re-deriving what the already-running `nmcli monitor` had just reported | 5s poll gated on `listVisible` (the AP list is only ever rendered by the control centre's Wi-Fi page), plus a separate unconditional 60s backstop. **23 + 24 spawns per 120s → 2/min: 33,840 forks/day → 2,880** |
| `Theme.qml` ran `inotify-watch.py -r <colorsRoot>` as a permanent `Process` | to notice hand-edits to `colors/` | one in-process `FileView` per theme palette plus one for `index.json`, all through the same 400ms debounce. **14.5 MB RSS** of a python process parked in `read()` |
| `Cava.qml` re-armed `cava` from a 1s timer in `onExited` | "if cava dies, start it again" | `running: root.running` — a **binding**, not an assignment, so nothing writes it from inside the exit handler. A latent 86,400 forks/day |

The `PowerProfile` one is the one worth reading twice, because it is a bug
class rather than a bug:

- The `Process` had **no stderr collector**, and the shell's fd 2 is
  `/dev/null`, so the tool's one line of explanation was thrown away on every
  rejection.
- `onExited` then started a **3,000ms timer that set `running = true`** again.
  So a permanently-failing command respawned itself every three seconds for as
  long as the shell was up: **19/min measured, ~27,360/day, ~95ms of CPU each,
  about 3.0% of one core, and entirely silent.**
- What it was duplicating was already in-process. The daemon property was
  already bound; the monitor process was never needed, only believed to be.

**The transferable rule: a restart timer on a command whose success nobody
can see is a fork loop with no floor.** If you cannot name the thing that
would make the retry stop, there isn't one.

The `Wifi` backstop is the other half and is deliberate, not an oversight:
`nmcli monitor` restarts itself 2s after it exits, so what the 60s timer
covers is the failure a self-healing watcher cannot cover — a monitor that is
*alive* and has stopped reporting, which would otherwise leave the bar icon
and `wifi status` describing a connection that no longer exists. It is a
second `Timer` rather than one `Timer` whose `interval` is rebound, because
reassigning `interval` on a running QML `Timer` restarts its countdown, so
toggling the pane would have kept resetting the backstop and could have
starved it entirely.

### Bluetooth: a pure view over `Quickshell.Bluetooth`

**Bluetooth is the purest case of the four.** `services/Bluetooth.qml`
is a view over stock `Quickshell.Bluetooth` and nothing else: it reads
`Bluetooth.defaultAdapter` and `adapter.devices.values`, and it lets
BlueZ's D-Bus object manager push the changes. It runs **zero
subprocesses** and parses no text. Two details that cost real time to
discover, both established by running the module against the live
BlueZ on this machine rather than from docs:

- **A `BluetoothAdapter` exposes no callable QML methods.** Power and
  discovery are *property writes* — `adapter.enabled = ...`,
  `adapter.discovering = ...` — not `setEnabled()`/`startDiscovery()`
  calls. Those method names do not exist on the type in 0.3.1.
- **The only `Timer` in the file is a 15s scan window.** Discovery
  otherwise leaves the radio scanning forever, and nothing else in the
  shell ever stops it. It is not a poll.

There is no `discovered` list any more. It existed only because
`bluetoothctl devices` reads BlueZ's on-disk cache — paired hardware
only — so an unpaired device had nowhere to appear. `nearbyDevices` is
now derived as the unpaired subset of `devices`, and the object manager
reports a device the moment it is seen. Verified on this machine: with
scanning on, an unpaired device reached `nearbyDevices`.

**Known gap, not a regression: BlueZ pairing agents.** Quickshell 0.3.1
registers no `org.bluez.Agent1` at all (confirmed against the installed
binary — no `Agent1`, `RequestPinCode`, or `RequestPasskey` symbols in
it), so a device that wants a PIN or a passkey cannot be answered from
QML. The `bluetoothctl pair` path this replaced could not answer one
either: it ran as a detached `Process` with piped stdio and no
terminal. A device that only needs a confirmation on its own side — the
common case — pairs through the module unchanged. Do not confuse this
with `Auth.qml`: polkit authenticates an *action* against a privileged
service, while a pairing agent is a plain session-bus client that
answers BlueZ's method calls. They share the word "agent" and nothing
else.

### The one caveat: `inotifywait` is optional

(also see Requirements in `README.md`). Where a service depends on it for
instant file-change notification and it isn't installed, that service
falls back to periodic polling instead. That's a real, different
performance/latency characteristic from the rest of the app, not a
rounding error — worth knowing rather than glossing over. After the
`Theme.qml` change above it is one caller, `BacklightDevice.qml`, watching
one sysfs node; nothing recursive is left.

## Five rules this tree now holds itself to

These came out of specific bugs, so they are written as rules rather than as
the anecdotes that produced them. Each says what to do, and names the thing it
prevents.

### 1. Derived geometry, never a hand-kept number

A window or panel's size is computed from its content. It is never a literal
that someone has to remember to update, and it never reads its own size back
(the quantity you read must not be derived from the thing you are deriving).

What this replaced, all three in the same commit:

| Was | Now |
|---|---|
| `SettingsApp.implicitHeight: 969` | `contentFlick.y + contentFlick.contentHeight + bottomInset` |
| `ControlCenter.panelHeight`: `display ? 564 : sound ? 719 : 514` | `drillTop + 14 + Math.max(140, activeFlick.contentHeight)` |
| the Island's settings height: `969` | `Math.min(settingsInner.implicitHeight, screenHeight - settingsTopInset - settingsBottomMargin)` |

Between them they left **~270px of dead space** under the settings window's
last card and **up to 370px** of dead black below a control-centre drill
page's last control. The failure mode is the same every time and it is
invisible in the source: the number is plausible, it is just wrong, and it
drifts further every time content grows. Two of the three were load-bearing
on the *wrong* side as well — 969 clipped the settings window, 700 clipped
the control centre's 719px sound view. This is the same bug class
`todos.md` records for the bar window.

### 2. Colour lives in the theme layer only

See **Colour lives in the theme layer, and nowhere else** above. One rule,
one exception (`Theme.fallbackColors`), one way to take an alpha.

### 3. One declaration site

A list of allowed values, a threshold, a colour alpha or a persisted setting
is written down exactly once, and everything that validates against it reads
that one declaration rather than keeping its own copy.

- `Theme.withAlpha` — 128 call sites, zero that build the `#aarrggbb` string
  themselves. The shape of the answer (alpha first) is therefore decided in
  one file.
- `PowerManager.lidActions` — the 11 actions logind accepts — and
  `validLidAction(value)`, which is a membership test against that list rather
  than a second list of the same strings.
- `BarConfig`, `MotionConfig` and `ConfigStore` for anything persisted.

The failure this prevents is a validator that quietly disagrees with what it
validates: two lists of the same strings, one of which gains an entry.

### 4. Per-screen state is not a singleton

A `Singleton` has exactly one instance. If one is built per screen, it is not
a singleton and must not be declared as one.

`BarConfigMonitors.qml` was `pragma Singleton` with a mutable `screenName`
and a `loadFor(name)` that assigned it. On one monitor this works, which is
why it survived: `IslandMetrics` builds one `IslandMetrics` per screen, and
on two monitors two Islands called `loadFor` on the one copy of the object.
That is not last-writer-wins either, because a singleton reached through
"tell me which screen" has no per-screen answer to give: once a second
instance asked, *no* override applied at all.

It is now a plain `QtObject` with `required property string screenName`:
constructed per monitor by the thing that already knows which monitor it is
for, with no writer for two screens to race over. That is the shape
`BrightnessMonitor`, `BrightnessMonitors` and `BacklightDevice` already use,
which is why the mistake read as safe — the plural filename looks like the
existing per-screen types and is the second half of the illusion.

### 5. An `IpcHandler` reply must be bounded

`clipboard list` is the largest reply in the tree and it was unbounded. At 750
entries it declared **433,018 bytes** against a **212,992-byte** socket send
buffer (`net.core.wmem_default`), so the tail never left the shell: the
declared length stayed 433,018 on every call while the delivered bytes varied
(219,264 and 255,808 across identical calls, read to EOF by a hand-written
client) and the JSON ended mid-string. Both clients hit it — this repo's
`qs-call` and the real `quickshell ipc call` — and both reported a
peer-closed socket and printed no reply.

Worse, it was not only a truncated reply: repeated oversized replies left the
shell's IPC server answering **every subsequent query** with `"Not ready to
accept queries yet."` at exit status 0. That is the same string
`tests/run.sh` retries through, so it presented as a slow reload rather than
as a wedged socket, and bounding the reply fixed it without restarting
anything.

The bound is `ipcReplyBudget: 65536`, in **bytes of the UTF-16BE string the
socket actually carries**, minus a 256-byte reserved envelope, charged as each
record is admitted rather than estimated. It is a deliberate margin — a third
of one send buffer, and a sixth of the smallest truncation observed — not a
threshold bisected on this machine, because another machine's
`net.core.wmem_default` may be smaller and this has to be right on a fresh
clone.

A byte budget rather than a count, and the reasoning is the useful part:
dropping the duplicated `rawPreview` took that same 750-entry reply from
444,586 to 313,892 bytes and truncating every preview to 120 chars took it to
313,940. Still far over. The payload is 750 copies of a ~290-byte JSON record
and only 750 copies of at most 101 characters of text, so at this history
length the *count* is the whole problem and a preview cap alone would not have
fixed it.

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

Every `qs ipc call <target> <function> [args]` this shell exposes.
Generated from `quickshell ipc show` — 93 functions across 15 targets.

`scripts/` and `tests/run.sh` check this table against the running shell, so
it cannot drift from what is actually callable.

| Target | Function | Notes |
|---|---|---|
| `audio` | `getVolume` `setVolume` `toggleMute` | volume only; sink/source enumeration is not exposed over IPC |
| `battery` | `getPercentage` `getStatus` `isCharging` | read-only |
| `bluetooth` | `connect` `disconnect` `refresh` `scan` `toggle` | connect/disconnect take a MAC |
| `brightness` | `get` `getFor` `set` `setFor` |  |
| `clipboard` | `copy` `del` `isAvailable` `list` `refresh` `wipe` | `del`, not `delete` — reserved word in JS |
| `mpris` | `next` `pause` `play` `playPause` `previous` `stop` `toggle` | the active player; `getActive <prop>` is not exposed |
| `nightlight` | `disable` `enable` `isEnabled` `setTemp` `toggle` |  |
| `notifications` | `clear` `toggleDnd` | a *subset* of `notifs`, not identical |
| `notifs` | `clear` `disableDnd` `enableDnd` `isDndEnabled` `list` `toggleDnd` | superset of `notifications` |
| `power` | `cycle` `get` | shorter alias over the same PowerProfile service |
| `powerprofile` | `cycle` `get` `isAvailable` `list` `set` | the service itself; `power` is its alias |
| `shell` | `bluetoothToggle` `brightnessDown` `brightnessUp` `ccBluetooth` `ccDisplay` `ccHome` `ccSound` `ccWifi` `clearNotifs` `closeAll` `mediaNext` `mediaPrev` `mediaStop` `mediaToggle` `nightLightToggle` `toggleCalendar` `toggleClipboard` `toggleControlCenter` `toggleLauncher` `toggleMedia` `togglePowerMenu` `toggleSettings` `toggleThemePicker` `toggleWallpaperPicker` | the `cc*` and `media*` names are what the control centre's drill sheets and the island's media card dispatch; the rest are keybind-facing |
| `theme` | `cycle` `cycleWallpaper` `get` `getWallpaper` `list` `publish` `set` | `publish` re-runs `scripts/publish-colors.py` — use it after hand-editing a theme's `colors.json`, the inotify watcher does not re-publish |
| `uis` | `isCalendarOpen` `isClipboardOpen` `isControlCenterOpen` `isLauncherOpen` `isMediaOpen` `isPowerMenuOpen` `isSettingsOpen` `isThemePickerOpen` `isWallpaperPickerOpen` | read-only state queries — safe to poll |
| `wifi` | `connect` `disconnect` `scan` `status` `toggle` | `connect` genuinely forwards a real password |

`hypr/scripts/qs-call <target> <function>` reaches the same functions over
the shell's IPC socket without launching a Qt process: 16ms against the real
client's 39ms, which is ~2.4x on every call and ~23ms saved per keypress. It
falls back to `quickshell ipc` when the socket is unavailable.

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

## Version sensitivity — four real examples, not hypothetical

Three separate crashes during development turned out to be Quickshell
API/module differences across versions, not logic bugs. A fourth assumption is
version-bound in the same way, and is the one that would fail silently:
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
4. **The runtime log lives at
   `$XDG_RUNTIME_DIR/quickshell/by-pid/<pid>/log.log`**, a symlink into
   `by-id/<instance>/log.log` — confirmed against the running 0.3.1
   shell, which announces the directory as its third log line
   (`Saving logs to ".../by-id/<instance>/log.qslog"`; `log.qslog` is
   its structured log, `log.log` the same content as plain text).
   Two facts hang off it. The shell's stdout and stderr are both
   `/dev/null`, so the journal is a *dead channel* for it:
   `journalctl --user -b _PID=<pid>` answers `No entries`, and the
   standing "check the journal after a reload" step cannot fail.
   And a restart leaves the old `by-id`/`by-pid` entries behind — 43 of
   them on this machine — so anything walking that directory must select
   a *live* pid rather than take the newest directory. `scripts/shell-log.sh`
   wraps all of it (oldest pid wins, `--pid` to override) and is where
   the `ERROR:` lines actually are. If an upgrade ever stops writing
   there, `shell-log.sh path` is what will say so instead of quietly
   reporting an empty log.
