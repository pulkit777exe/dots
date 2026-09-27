# Changelog

Round-by-round debugging history — every crash actually hit against a
real Quickshell instance, real bugs found by static audit, and how
each was fixed. Kept separate from `README.md` on purpose: this is a
historical record of what changed and why, not a description of the
current state. Where an entry describes something that was later
superseded (an old theme list, an intermediate default value), that's
correct as *history* — check `README.md`/`ARCHITECTURE.md` for what's
actually true now, not the earliest matching sentence in this file.

## Round 1 — first real crash: `Qt5Compat.GraphicalEffects`

First `qs` run failed entirely:
```
caused by @components/Surface.qml[2:1]: module "Qt5Compat.GraphicalEffects" is not installed
```
`Surface.qml` used that module's `DropShadow` for its drop shadow.
Since `Surface` underlies nearly every surface in the shell, one
missing optional package took the whole thing down at load — nothing
rendered, not just the shadow. Fixed by removing the dependency
entirely: `Surface.qml`'s shadow is now approximated with a few
stacked, enlarged, increasingly-transparent copies of its own shape,
using nothing beyond core `QtQuick`.

## Round 2 — a fabricated signal, plus one waiting to happen

Second run got further, then failed differently:
```
caused by @services/Brightness.qml[35:12]: Duplicate signal name: invalid
  override of property change signal or superclass signal
```
`Brightness.qml` declared `property int level` *and* an explicit
`signal levelChanged(int percent)` — QML auto-generates a
`levelChanged` signal for any property named `level`; redeclaring one
with that exact name is fatal at load, not a warning. Fixed by
renaming the explicit signal to `osdRequested` (its actual purpose) in
both `Brightness.qml` and, for consistency, `Volume.qml` (which hadn't
crashed — different property name, no collision — but shared the
same risky pattern).

Scripted a scan for this exact bug class (`signal <X>Changed` colliding
with `property <X>`) across every file rather than waiting for the next
one to get reported, and found a second, not-yet-triggered instance:
`Bluetooth.qml` had `property var devices` *and* `signal
devicesChanged()`. Fixed by removing the redeclaration outright — no
consumer depended on the explicit emission, the property assignment
already fires the built-in signal.

Also found while tracing the call chain: `OSD.qml`'s
`showVolume()`/`showBrightness()` were never called from anywhere —
the surface existed and was mounted, but nothing connected
`Volume`/`Brightness`'s signals to it. Added the missing `Connections`
blocks in `shell.qml`.

## Round 3 — six reported issues, functional not crashes

No crash log this round — six behavioral reports, worked one at a
time:
- **Bar hover was growing the reserved screen space.** `exclusiveZone`
  was bound to the bar's *live* height (34px collapsed → 135px
  hover-expanded) instead of its resting size, so every hover visibly
  shoved tiled windows down and back. Pinned to a constant.
- **Bar clicks weren't registering, only hover worked.** Root cause
  never reached full certainty through static analysis. Two concrete
  things fixed regardless: added a missing `mask` to `barWindow` (an
  invisible full-width dead zone was blocking clicks to windows
  underneath), and switched the collapsed pill's tap handler from
  `TapHandler` to `MouseArea` — not provably "the" cause, but the
  pattern Quickshell's own official bar tutorial uses for exactly this
  interaction.
- **"Binds don't work"** — audited `IpcHandler` wiring, found no bug in
  it, but found a real, relevant historical Quickshell issue: a past
  release had "hard to debug issues with Process, IpcHandler,
  NotificationServer, and GlobalShortcut not working depending on where
  you put them in a QML file." Worth checking Quickshell version if
  binds silently do nothing.
- **Brightness had no OSD feedback, or any feedback at all.** Traced to
  a real parsing bug: `brightnessctl -m` machine-readable output is
  5 fields (`id,class,current,percent%,max` — confirmed against
  `brightnessctl`'s own source), not the 6-field format the code
  assumed. The discovery condition could never match real output, so
  `available` never became true and the whole service silently never
  initialized.
- **Wi-Fi**: `disconnect()` hardcoded the device name as literally
  `"wlan0"` — fails silently on predictable-interface-naming systems
  (Fedora's default) where the real name is something like `wlp3s0`.
  Fixed to disconnect by connection id (SSID) instead, which needs no
  device name. Also made the network-scan parser use terse
  (machine-readable) `nmcli` output for consistency with the file's
  other two queries, instead of fragile human-readable-table parsing.

## Round 4 — my own fabricated API, plus a full re-audit

```
caused by @shell.qml[98:51]: Cannot assign to non-existent property "enabled"
```
`Region { enabled: ... }` — an invented property. `Region`'s real,
documented properties are `x, y, width, height, item, shape,
intersection`, confirmed against actual docs this time. By the time
this was reached, it had already been hand-patched (in the uploaded
copy under review) to `item: condition ? wrapItem : null`, which is
correct — verified that fix rather than redoing it.

Since the codebase had grown substantially, did a full re-audit rather
than stopping at the one report:
- Found a second guaranteed crash before it was reported:
  `CustomShortcut.qml` (a correctly-written shim over
  `Quickshell.Hyprland`'s `GlobalShortcut`) was used in 11 places
  across 6 files but never registered in `services/qmldir` — a
  guaranteed cascading "Type unavailable" failure. Fixed, and checked
  all 11 usage sites sit at a safe nesting depth given the historical
  placement-sensitivity issue above.
- Cross-checked API contracts (not just syntax) for the by-then much
  larger `Wifi.qml` and new `Media.qml` against every call site in the
  surfaces. Both held.
- Confirmed `components/`/`surfaces/` don't need explicit `qmldir`
  files at all (Quickshell auto-synthesizes one) — only directories
  declaring `singleton` types do.
- `ControlCenter.qml` had been rewritten and lost the press-scale
  feedback its old custom tile component had. Added it to
  `ListRow.qml` instead of re-patching the same spot — systemic rather
  than local, since `ListRow` is used broadly.

## Round 5 — the 6-theme system, matched wallpapers, Power Menu

**Replaced the theme system** with exactly six presets: `ariadne`,
`catppuccin`, `everforest`, `gruvbox`, `horizon`, `monochrome` — this
superseded an earlier five-preset set (`nord`, `dracula`, `catppuccin`,
`gruvbox`, `everforest`). Where a real published palette exists, used
it, verified against the actual source rather than guessed:
Catppuccin/Gruvbox/Everforest were already accurate in the prior
`themes.json`; Horizon's hex codes were pulled from
horizontheme.netlify.app directly. `ariadne` isn't an established
public scheme (searched, found nothing) — designed openly (indigo +
gold, motivated by the myth) rather than presented as sourced.
`monochrome` keeps slightly-desaturated (not fully gray)
danger/warning/success — a fully colorless destructive-action button
is a real usability regression, not just a look.

**Wallpapers are generated, not sourced** — each one built
deterministically from that theme's own real palette
(`scripts/generate-theme-wallpapers.py`, PIL), so the color match is
structural rather than approximate. Matched the existing
catppuccin/gruvbox/everforest wallpapers' visual style (soft
overlapping gradient circles) for the three new ones.

Cleaned up real leftover cruft found while doing this: `ThemePicker.qml`
still had its original 9-entry placeholder demo data as its fallback
default (`anime`, `e-ink`, `gruvbox-material`, `industrial` — names
from an early scratch draft); `Theme.qml`'s own initial default was
still the now-removed `"nord"`; a stale `state/theme-state.json` from
earlier testing referenced dropped theme keys with `dynamicMode` left
on from a test session — removed rather than shipped.

**Built the Power Menu** (`surfaces/PowerMenu.qml`): Lock/Suspend/
Log Out/Reboot/Power Off. Reboot and Power Off need a second tap
within 3 seconds to actually fire (every real desktop environment
guards these two specifically — they're the only actions here that
can lose unsaved work outright). Log Out/Reboot/Power Off prefer
`hyprshutdown` over bare `hyprctl dispatch exit` /
`systemctl reboot|poweroff` — checked against Hyprland's current wiki,
which explicitly warns the bare `exit` dispatcher "kills apps instead
of letting them exit cleanly." Falls back to the blunter commands only
if `hyprshutdown` isn't installed.

Caught one real bug before shipping: `PowerMenu.qml`'s root `Surface`
had no `implicitHeight` — the `shell.qml` wrap that hosts it binds its
click-mask geometry to exactly that property, so without it the mask
would have been zero-area. Same failure class as Round 3's Bar click
bug: would have rendered perfectly and been entirely unclickable.

## Round 6 — a real Settings App, not just individual popups

Built `surfaces/SettingsApp.qml`: sidebar with all ten reference nav
items, content pane via `Loader`. Two pages are fully live, not
mockups:
- **Bar & Island** — every slider is a persisted property on a new
  `services/BarConfig.qml`; `Bar.qml` reads its shape from there
  instead of hardcoded defaults.
- **Motion** — Reduce-motion toggle + 4 sliders on a new
  `services/MotionConfig.qml`, wired into `Bar.qml`/`Slider.qml`/
  `ListRow.qml`'s actual animations. `SpringAnimation` has no duration
  parameter (governed by spring/damping/mass instead), so
  `movementMs` only applies to the plain `NumberAnimation`/
  `ColorAnimation` fades — bounce and reduce-motion are what actually
  reach the spring-based transitions.

The other eight sidebar pages are explicit placeholders — each states
plainly it has no real config service yet, rather than faking content.

Caught one bug before shipping: an early draft of the placeholder page
used `parent.parent._current` to reach a property on its own root
`ColumnLayout` — off by one level in the actual parent chain (resolved
to an intermediate `RowLayout` instead), which would have silently
shown a blank icon/title rather than crashing. Fixed with a proper
`id` reference.

## Round 7 — general re-audit, not tied to a specific report

No new report this round — did a systematic sweep instead of chasing
one symptom.

**Found: "Peace" (Do Not Disturb) had silently regressed out of
`ControlCenter.qml`.** The backend was already fully built —
`Notifications.dnd`, popup-suppression logic, cross-restart
persistence — just never wired to a UI control after an earlier
rewrite dropped it. Added the row back.

**Found while wiring it: `Notifications.toggleDnd()` isn't actually
callable from QML.** It only exists inside two `IpcHandler` blocks —
reachable via `qs ipc call`, but `IpcHandler` functions aren't exposed
as regular methods on the singleton itself. Caught by extending an
API cross-check script (built specifically to catch this class of bug)
to also flag matches that only exist at `IpcHandler` nesting depth, not
just missing entirely. Fixed by toggling the writable `dnd` alias
directly instead of calling a function. Then ran the same check across
every `Service.member` call in the whole tree, both directions
(surfaces/components calling services, and services calling other
services) — everything else resolved cleanly.

Checked and confirmed **not** bugs, worth recording so they don't get
re-flagged: `PowerMenu.qml`'s inline component reading the enclosing
`Surface`'s scope directly (`root.accent` etc.) — verified against Qt's
own docs, this is documented, correct behavior; earlier caution against
this same pattern in `ThemePicker`/`WallpaperPicker` wasn't actually
necessary, just extra-conservative. Also re-checked every wrapped
surface in `shell.qml` for the Round 5 `implicitHeight` bug class (all
clean) and searched for any other fragile `parent.parent`-style
reference anywhere in the codebase (none exist).

## Round 8 — cliphist integration, the keybind-coverage gap, and this restructuring

**Built clipboard history** (`services/Clipboard.qml` +
`surfaces/ClipboardHistory.qml`), wrapping `cliphist` + `wl-clipboard`.
Verified against `cliphist`'s own README rather than assumed: `list`
outputs tab-separated `<id>\t<preview>` lines; `decode`/`delete` take
that id-prefixed line via **stdin**, not a CLI argument, and `decode`'s
stdout is the raw original content — which can be binary (images).
That last point drove the actual design: copying an entry back to the
clipboard is one shell pipeline (`cliphist decode | wl-copy`) so raw
bytes never pass through QML/JS string handling, with only the numeric
id interpolated in — as a positional shell argument, never
string-concatenated, so arbitrary preview text can't reach the shell
parser. Unlike most services in this project, `Clipboard.qml` does
start its own watcher daemon (`wl-paste --watch cliphist store`) rather
than expecting the user to add it to their Hyprland config separately
— justified because that daemon has no purpose beyond this one
feature, unlike wallpaper/night-light daemons which serve independent
purposes this project deliberately doesn't take over starting.

**Found a much larger keybind-coverage gap while checking "make sure
keybinds work."** This codebase implements every toggle two ways
(`IpcHandler` and `CustomShortcut`/`GlobalShortcut`), but only the
`IpcHandler` path — and only 5 of its 8 functions — had ever been
documented. Checked Quickshell's actual docs for how `GlobalShortcut`
is meant to be triggered from Hyprland: a completely separate bind
syntax, `bind = <mods>, <key>, global, <appid>:<name>`, not `exec`.
Every `CustomShortcut` in this codebase left `appid` at its default
(`"quickshell"`). Extracted every `IpcHandler` target (15 of them,
covering 60+ functions) and every `CustomShortcut` name (13) directly
from source and documented all of it — nine of those thirteen
shortcuts (brightness, all four media controls, Bluetooth toggle,
Night Light toggle, clear-notifications) had **no other way to be
triggered at all**. Also found and fixed a real Hyprland-specific
gotcha for the media/brightness binds specifically: `binde` + `global`
triggers an indefinite repeat per a confirmed upstream Hyprland issue,
so those binds are documented with plain `bind`, not `binde`.

**Restructured the documentation itself**, prompted by an external
review that found real, confirmed contradictions in the previous
single-file `README.md` — verified each claim against source before
acting on it rather than trusting the review blindly, and every one
checked out:
- `Region.enabled` was described in one place as a fatal, fixed
  mistake, and in another as "the most stable pair" still in current
  use — a stale sentence left over from before that bug was found.
- The theme section asserted both "exactly six themes now" and,
  elsewhere, "`themes.json` has five presets: Nord, Dracula,
  Catppuccin, Gruvbox, Everforest" — Nord was also separately described
  as no longer existing, three mutually contradictory statements about
  the same file.
- The opening claimed the whole system is "event-driven, not polled,"
  while the requirements section separately admitted a polling
  fallback without `inotifywait` — true, but not what the opening
  sentence said.
- The Wi-Fi IPC table implied `connect <ssid> <password>` works fully,
  while a separate "known simplifications" note said the actual UI
  always sends an empty password — both are true simultaneously
  (checked `Wifi.qml`'s `IpcHandler` directly: the function itself
  genuinely forwards a real password; the gap is specifically in
  `WifiSettings.qml` never prompting for one), but stated baldly
  side-by-side they read as a flat contradiction.

All four traced to the same root cause the review named directly: one
file had been repeatedly appended to across every round (debugging
narrative, architecture notes, and current-state documentation all
interleaved) rather than rewritten around the current state each time.
Split into this file (history), `ARCHITECTURE.md` (design/reference,
reconciled to the actual current source), and a `README.md` cut down
to what a new reader actually needs first.

One process note worth being honest about: across this whole project,
a section-header line got accidentally consumed by a `str_replace` edit
five separate times — using the header itself as the match boundary and
forgetting to re-emit it in the replacement text, orphaning the content
that used to sit under it. Caught and fixed every time it happened, but
five times is a real pattern in how those particular edits were made,
not five unrelated slips.

## Round 9 — hover-scale bug, four dead-call bugs, missing Wi-Fi password UI, Qt5Compat fully removed, two orphaned settings pages wired in, 47 layout warnings, README.md finally written

Reference-image pass first: two dots on the pill had no hover state at
all — added 1.0→1.05 scale + 1px shift, but used `MouseArea.hovered`,
which doesn't exist (`MouseArea` has `containsMouse`; `hovered` is
`HoverHandler`/`Button`). Caught by `qmllint` on a later pass, not by
inspection — the property silently evaluated to `undefined` (falsy),
so the hover effect just never fired. Fixed to `.containsMouse`.

PowerMenu's accent-filled "primary" tile was on Lock; the reference
image clearly shows Power Off filled instead. Swapped.

`Qt5Compat.GraphicalEffects` — Round 1 fixed this for `Surface.qml`'s
shadow but two more usages survived in `Island.qml` and
`MediaPlayerSurface.qml` (both `OpacityMask` for circular/rounded
avatar art). Same crash risk Round 1 already documented as fixed
project-wide, just wasn't. Replaced both with plain
`Rectangle { clip: true }` — no shader/effect module at all, since a
static circular/rounded mask doesn't need one. Import fully gone from
the codebase now, verified with a repo-wide grep.

Four more dead calls, all the same shape (call/read something that
doesn't exist on the singleton, found by cross-checking every settings
page's service calls against the service's actual declared members):
- `NotificationsPage.qml`: `Notifications.toggleDnd()` — no such
  function, only a plain `dnd` alias. DND toggle in Settings was
  silently dead. → `Notifications.dnd = !Notifications.dnd`.
- `ControlCenterPage.qml`: `Wifi.activeSsid` (real name: `ssid`) and
  `Bluetooth.powered` (real name: `enabled`) — status cards in
  Settings could never show the real network name and always rendered
  Bluetooth as "Off" even when connected.
- `LockScreenPage.qml`: `Auth.lock()` — doesn't exist anywhere on
  `Auth`; locking lives as a local function in `PowerMenu.qml` or
  inline `Quickshell.execDetached(["hyprlock"])` in `ControlCenter.qml`.
  Settings' Lock button was dead. → same `execDetached` call.

Wi-Fi password flow: `ControlCenter.qml`'s Wi-Fi sub-page called
`Wifi.connectToNetwork(ssid, "")` unconditionally — a secured network
could never actually be joined from this UI. `WifiPasswordDialog.qml`
existed, fully built, completely unwired. Traced back further:
`WifiSettings.qml` (now deleted, see below) is where CHANGELOG history
shows this exact gap was first identified, pre-Control-Center; it
never got fixed there either, and the file was abandoned when Control
Center absorbed Wi-Fi management, silently carrying the same bug
forward. Wired `WifiPasswordDialog` into `ControlCenter.qml`'s Wi-Fi
view properly: try connecting with an empty password first (covers
NetworkManager-cached credentials), only prompt if that specifically
fails with `needsPassword`.

Reproducibility, three real ones, not style:
- `startup.lua` hardcoded `hyprctl hyprpaper wallpaper` to a specific
  `~/Downloads/everforest/...` path — broken on any machine without
  that exact file, and redundant besides: `Theme.qml` already applies
  the correct per-theme wallpaper dynamically on its own. Removed;
  `startup.lua` now only starts the `hyprpaper` daemon.
- `kitty.conf` never `include`d the generated `current-theme.conf`,
  and had no `allow_remote_control`/`listen_on`, so `publish-colors.py`'s
  live `kitty @ set-colors` was silently failing. Fixed both.
- `general.lua` only ever set `col.active_border`/`col.inactive_border`
  live via `hyprctl keyword` on a theme switch — a fresh login before
  the first switch got Hyprland's stock border color, not the saved
  theme. Now seeds both from `colors/hyprland.conf` at config-load
  time, live updates still take over from there.

Two settings pages — `DisplayPage.qml` (57 lines) and `MediaPage.qml`
(151 lines) — existed fully built and correctly wired to their real
backing services (verified line-by-line against `Brightness.qml`,
`NightLight.qml`, `ConfigStore.qml`), but were never added to
`SettingsApp.qml`'s navigation. This is also what the mysterious
skipped page-index-1 turned out to be. Added both (Display fills index
1, Media takes index 10), updated the nav list and both back/forward
page arrays together so they can't drift apart again.

qmllint (`qt6-declarative-dev-tools`, installed fresh — wasn't in the
container) caught real, environment-independent issues beyond the
above: 47 instances of `width`/`height` set directly on children of
`RowLayout`/`ColumnLayout` instead of `Layout.preferred*` (fixed
across `SettingsApp.qml`, `BarIslandPage.qml`, `MediaPlayerSurface.qml`,
`ControlCenter.qml` — each verified by hand before editing, not sed'd
blind); a handful of genuinely-dead imports. One self-inflicted near-miss
worth recording: a first attempt at removing a redundant
`PagePanel { width: parent.width }` used a regex that also stripped the
*inner* `BarIslandPage { width: parent.width }` — which is genuinely
needed, since `BarIslandPage` is `ColumnLayout`-rooted and sits inside
`PagePanel` (a plain `Item`, not a `Layout`, so that assignment was
never actually the warning). Caught before moving on, restored.

Also surfaced ~300 "unqualified access" warnings (implicit
context-property lookup inside delegates/`Connections`, legacy but
fully working — `pragma ComponentBehavior: Bound` is the modern fix)
across ~30 files. Converted `SettingsApp.qml`'s nav-list delegate as a
template (`required property var modelData` + qualifying every
reference), left the rest for a slower pass — the scale here means
blind sed is the wrong tool, and this class isn't an actual bug the
way everything above was.

`BluetoothSettings.qml`, `WifiSettings.qml` (orphaned, unreferenced
anywhere — confirmed via `SettingsApp.qml`'s page registry containing
no trace of either) and `kitty/theme-island.conf` (referenced a
nonexistent `apply-theme-colors.sh`) deleted.

`README.md` — referenced by `ARCHITECTURE.md` and this file since
Round 8 (see: "a `README.md` cut down to what a new reader actually
needs first") but never actually existed in the repo. Written now:
Requirements (Fedora-specific — Hyprland and Quickshell both need a
COPR, and Quickshell's Qt6 version must match the system's, a live
gotcha as of this writing), install instructions, known gaps. Root
`install.sh` written alongside it — symlinks `colors/`, `hypr/`,
`kitty/`, `quickshell/`, `vlc/`, `Thunar/` into `~/.config/` and checks
for the binaries README.md's Requirements table lists, backing up
anything already in place rather than overwriting it.
