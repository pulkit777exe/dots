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

## Round 10 — Bluetooth onto the stock module, and three things the doc had wrong

Driven by `docs/SIMPLIFICATION-REVIEW.md`, which compared this tree against
ChillPill-Shell and argued that `services/Bluetooth.qml` should be a view
over the stock API rather than a `bluetoothctl` scraper. The argument held
up. The review's own details did not, in three places, and those are
corrected in the file itself.

**`services/Bluetooth.qml` rewritten on `Quickshell.Bluetooth`: 8
subprocesses → 0, and no text parsed at all.** The old service polled
`bluetoothctl` (3 spawns per cycle) plus one per toggle / scan / connect /
disconnect / pair / forget, and scraped `show`, `info` and `devices` output.
It is now a pure view: `Bluetooth.defaultAdapter`, `adapter.devices.values`,
and BlueZ's D-Bus object-manager change signals. 198 → 166 lines.

Two things that were only settled by running the real module against this
machine's live BlueZ, not by reading the docs:

- **A `BluetoothAdapter` exposes no callable QML methods.** Adapter power
  and discovery are *property writes* — `adapter.enabled = ...`,
  `adapter.discovering = ...`. `setEnabled()` / `startDiscovery()` do not
  exist on the type in 0.3.1. The device-level methods (`connect()`,
  `disconnect()`, `pair()`, `forget()`) do exist, and those are what the
  service calls.
- **`discovered` is gone, and its removal is the point.** It existed only
  because `bluetoothctl devices` reads BlueZ's *on-disk cache* — paired
  hardware only — so an unpaired device had nowhere to appear and Nearby
  was permanently empty. `nearbyDevices` is now derived as the unpaired
  subset of `devices`. Verified on this machine: with scanning on, an
  unpaired device reached `nearbyDevices` through the module.

The one remaining `Timer` is a 15s scan window that resets `discovering`
to false — not a poll. Discovery otherwise leaves the radio scanning and
nothing else in the shell would stop it.

**Known gap, recorded rather than glossed: BlueZ pairing agents.**
Quickshell 0.3.1 registers no `org.bluez.Agent1` — `strings /usr/bin/
quickshell | grep -ci agent1` returns 0, and there are no `RequestPinCode`
or `RequestPasskey` symbols either — so a device that wants a PIN or a
passkey cannot be answered from QML. **This is not a regression.** The
`bluetoothctl pair` path it replaced ran as a detached `Process` with
piped stdio and no terminal, so it could not answer one either. A device
that only needs a confirmation on its own side, the common case, pairs
unchanged. The earlier review assumed stock Quickshell registered its own
agent at `/quickshell/agent`; it does not, and the review also suggested
checking this against `Auth.qml`'s polkit flow. Those are unrelated
mechanisms — polkit authenticates an *action* against a privileged
service, a pairing agent is a plain session-bus client answering BlueZ's
method calls.

**`scripts/recovery.sh`: the reap list is two services, not three.** The
`bluetoothctl monitor` entry is removed, along with the comment naming it.
That entry had been naming a process that never existed, which is how the
documented design and the code drifted apart for so long. What remains is
Clipboard's `wl-paste --watch cliphist store` and Wifi's `nmcli monitor`.
Bluetooth needs no reap entry because it now spawns nothing. The
reparent-to-init-only guard is unchanged.

**`services/Notifications.qml`: the duplicated guard idiom, collapsed —
and explicitly *not* a split.** Six `Connections` blocks each carried a
hand-rolled `property bool initialised` + `property <T> wasX` + a
`wasX !== X` re-check before notifying. They now share one shape: a single
`property bool seenStartupChange` that swallows the first change and then
trusts the handler's own value. A 3-second `systemNotifsReady` `Timer` that
only gated the Bluetooth block went with it. The file is **still 952 lines
and still does all four jobs** — daemon state, the `notify()` formatter, ten
`Connections`, two `IpcHandler`s. `git diff --numstat` reads 102 insertions
against 206 deletions, every hunk a pure deletion; the net −104 lines look
like an extraction and are not one. Splitting the file is a separate, larger
change and was left alone.

**`surfaces/ControlCenter.qml`, two changes plus a real bug.** The cells
each declared eleven children and hid ten of them with
`visible: controlType === "..."`, so ninety controls were built to draw
nine; they are now one `Loader` over a `sourceComponent` switch. The 64-row
`rowTops()` table was rebuilt by `rowTop()` for every cell and depends on
`Notifications.active`, so every toast rebuilt it 64 times — it is now a
`readonly property var`. And the actual bug: **a drill page was drawn over
the home grid without blocking input underneath it.** The Bluetooth
page's on/off switch lands exactly on the Night Light disc in row 1, so one
tap turned Bluetooth off *and* the night light on; the same leak made a
drill page's back arrow re-open the page it sits on. Cells a drill card
covers now stop taking input while it covers them, and row 0 — which ends
above the drill line — keeps working, which is what makes it the page
switcher.

### Also fixed: `lint.sh` was linting with the wrong major version of `qmllint`

Found while trying to state the qmllint status honestly, and it is the same
false-clean this round is otherwise about. On a machine with both the Qt5
and Qt6 Qt packages installed, `/usr/bin/qmllint` is the **Qt5** binary:
`qmllint --version` reports `qmllint 1.0`, and on this tree it exits 0 with
a **zero-byte log** — it analyses nothing at all. The "qmllint: clean" line
this script has been printing therefore said almost nothing, and it would
have said the same about a file importing a module that does not resolve,
because that case also exits 0 silently. Three changes:

- Resolve a real Qt6 linter (`qmllint-qt6`, then the `qt6/bin` paths, then
  the unversioned name only if its version string is 6.x), and print which
  one ran. Under it the tree is **0 errors, ~3000 warnings** — reported as
  a count with the full log path, not as a pass.
- **An empty log is now a failure, not a pass.** It is indistinguishable
  from never having analysed anything, which is the failure mode above.
- Fixed the severity match while there. It was `grep -E "Error|error:"`
  over the whole log, which also matches a *warning* whose echoed source
  happens to contain an error-shaped name — `FileViewError.FileNotFound` at
  `Notifications.qml:402` is one, and it briefly made the whole tree look
  like it had a lint error. Severity is now anchored to the start of the
  line. There are 0 errors under the Qt6 linter.

New check: **`quickshell modules`.** Every `Quickshell.*` module URI the
tree actually imports (11 of them) must appear as an exact line in
`strings /usr/bin/quickshell`. This is the check qmllint structurally
cannot be — it has no import path for a module Quickshell registers
in-process, which is the same blind spot that made its clean exit
meaningless. All 11 pass today. Both new checks were proven to fire: a
stub linter that exits 0 silently fails on the empty-log assertion, and a
synthetic file importing `Quickshell.TotallyMadeUp` fails the module check
while a commented-out `import Quickshell.Io` is correctly ignored.

One thing the newly-working linter did **not** find: no `[unresolved-type]`
or `[incompatible-type]` warning is a dead service call, so the Round 7 bug
class is not hiding in the ~3000. `scripts/ipc-audit.py` remains what covers
it, and it is clean.

### Verification status for this round

Bluetooth: verified at runtime against this machine's live BlueZ — adapter
resolves, device list populates, an unpaired device reached
`nearbyDevices`, adapter power toggles. `./scripts/lint.sh` clean,
`./tests/run.sh` 15/15, `check-ipc-table.py` 93 functions across 15 targets
(the debug `probePut`/`probeClear` pair was removed during this round, which
put the count back where it was). Not verified: PIN/passkey pairing, which is
the gap above. Notifications and ControlCenter: static verification plus
`lint.sh` / `tests/run.sh`; the Control Center drill-input fix has not been
exercised by hand on screen.

---

## Round 11 — the tree stops being allowed to be big, and stops hiding what it costs

This round is mostly structural, but the reason it happened is worth
stating first: three separate defects this session were only findable
because the code was in the way of reading them. A 2,277-line control
centre owned a private colour palette that matched no shipped theme. A
`pragma Singleton` held per-monitor state, so "the second screen uses the
first screen's overrides" was true and invisible. An `IpcHandler` reply
larger than one socket buffer truncated *and* wedged the IPC server for
minutes, reporting `Not ready to accept queries yet.` at exit status 0 —
which is the exact string the test suite retries through, so it read as a
routine reload.

### Bluetooth needs no scraper at all

`services/Bluetooth.qml` went from 262 lines and **8 subprocesses** to
163 lines and **zero**: a pure view over stock `Quickshell.Bluetooth`,
every property a binding on a BlueZ signal. The `bluetoothctl` text
scraper it replaced existed because `bluetoothctl devices` reads BlueZ's
*on-disk cache* — paired hardware only — so a stranger device had nowhere
to appear, and a `scan on` whose output was discarded gave it nowhere to
land. The object manager reports a device the moment it is seen.

Two things cost real time and are now written down in
`ARCHITECTURE.md`: a `BluetoothAdapter` in 0.3.1 has **no callable QML
methods** (power and discovery are property *writes*), and Quickshell
registers **no `org.bluez.Agent1`**, so PIN/passkey prompts cannot be
answered from QML. That gap is not a regression — the old
`bluetoothctl pair` ran as a detached process with no terminal and could
not answer one either — but it is a gap, and the pane now shows
`Read only` with the reason rather than an editor that cannot work.

### The tree is split along real seams, and the dead weight is gone

Fifteen files exceeded the ~400-line guideline; the largest was 2,277.
Now **none does** — the largest is 397. Every extraction went into a
sibling file that names its own concern, and four provably dead files
(676 lines, zero references, no `qmldir` entry, no `Loader` with a string
source) were deleted rather than maintained.

`ControlCenter.qml` 2,277 → 274, with its five drill pages in `cc/` and
its design tokens and controls as `Cc*` components. `Notifications.qml`
1,046 → a 224-line singleton plus seven collaborators. `Island.qml` 833 →
109. `Theme.qml`, `Brightness.qml`, `Wifi.qml`, `Clipboard.qml`,
`Launcher.qml`, `AuthDialog.qml` and six more split the same way.

The net effect is the shape the contract asks for: **+3,670 / −8,734**
lines across 71 files. The codebase got *smaller* while the file count
grew to 138.

Three traps recurred enough to be worth recording, because each one
silently takes the whole configuration down rather than one surface:

- A `Process` declared, documented, and **never started** — an extraction
  left the `Component.onCompleted { someProc.running = true }` behind in
  the file it came from (`BacklightDevice.qml`).
- A child object written inside a `QtObject {}` is a **compile error**;
  `qmllint` only warns.
- A new file reading `Theme`/`ConfigStore` **without** `import
  "../services"` loads fine and renders **black text on a dark fill**.
  Five files shipped that way before anything caught it.
  `scripts/lint.sh` now has a `service-missing-import` rule, proven
  against eleven fixtures.

### What being event-driven was costing

The shell's own CPU was 0.225% of one core, which is the number you
would measure and the number that lies. It *caused* ~3.8% of a core in
short-lived children, and **79% of that was one bug**:

`services/PowerProfile.qml` ran `powerprofilesctl monitor`, which is
**not a valid subcommand** — it exits 2 on a usage error. `onExited`
started a 3-second timer, which restarted it, forever: **27,360 forks
per day**, ~95ms of CPU each at 98% utilisation. It survived 13 hours
and 26 reloads silently because the process had no `stderr:` collector
and the shell's fd 2 is `/dev/null`, so the usage error was discarded.
It is now an event-driven subscription on Quickshell's `PowerProfiles`
singleton: **19 spawns/min → 0**.

| fix | before | after |
|---|---|---|
| `PowerProfile` monitor loop | 27,360 forks/day, 3.0% of a core | 0 |
| `Wifi` 5s `nmcli` poll (duplicated a monitor already running) | 33,840 forks/day, 0.55% | 2,880, 0.047% |
| `Theme` recursive python inotify watcher duplicating a `FileView` | 14.5 MB RSS | 0 |
| `Cava` restart loop (latent, not firing) | up to 86,400 forks/day | structurally impossible |

`Wifi`'s fix kept a 60s unconditional backstop, because the failure mode
of removing it is a dead monitor stranding the UI rather than a slow one.
`Cava`'s `running` is now a *binding*, so the loop cannot self-arm.

### Colour lives in the theme layer, and nowhere else

165 hex literals and 116 `Qt.rgba(1, 1, 1, x)` scrims outside
`themes/`: **all 281 are gone.** The work started where it was worst —
the control centre read the theme exactly twice, for `accent` and
`accentText`, and painted every background from a private 11-token
gruvbox palette of which **10 existed in no palette at all**. It is not
even self-consistent: `bgSurface` and `bgCard` were the same value under
two names.

Every alpha now maps to a token via `Theme.withAlpha`, which already
existed and was already the production idiom. `StyledText`'s `clock` and
`mediaTitle` cases were sharing one `return` by coincidence and were
split so routing one through the theme cannot silently recolour the
other. The two genuine dims — a scrim over arbitrary content, a drop
shadow — stayed `Qt.rgba` on `panelFill` with a comment saying why.

**Two findings that the sweep exposed rather than caused.** All six
palettes are dark, so the contract's "so light mode works" motivation is
exercised by nothing that ships; the real justification is theme
switching. And substitution **changes rendered RGB everywhere** — `text`
deviates from `#ffffff` by 31/255 on monochrome and 119/255 on horizon,
where every secondary text goes salmon. Contrast tables for every rung
on every theme are in the working notes; this is a visual change on five
of six themes and should be reviewed as one.

`ariadne` was the worst case and is fixed: its surface ramp *ascended
into the light* (`surfaceElevated` at luminance 0.68 against 0.65 text),
so **no text colour could ever be legible** on it — text needed
luminance ≥3.24 against a physical maximum of 1.0. Its text now reads
5.12–9.85:1 across every backdrop, and `muted` 4.05–4.51:1 on cards.

### Bugs found and fixed

- **Sound and display drill pages never opened.** `drillRequested` is
  declared `(string view, point origin)`; those two call sites passed
  one argument, so QML raised `Insufficient arguments` and the handler
  never ran. Wi-Fi and Bluetooth passed both and worked. They had been
  written without an origin because `SliderCard` had no `originInRoot()`
  helper, unlike `CcPill` — added.
- **Every keybind's fallback was broken.** `qs-call`'s fallback ran
  `quickshell ipc <argv>`, omitting the `call` subcommand, so it exited
  106 "A subcommand is required". It was dormant because the fast path
  normally wins.
- **Notification history was lost on every restart.** One saved toast
  without an `urgency` key made the parse throw inside its `try`, and
  the restore returned `[]`. Watcher toasts are filed *without* urgency
  because `JSON.stringify` drops undefined, so this was reachable, not
  theoretical.
- **`clipboard list` truncated over IPC** — 433,018 bytes declared,
  ~219KB delivered at a varying size per call. Now a bounded 65,350-byte
  window of `{total, returned, truncated, entries}`. An oversized reply
  does not merely truncate: it leaves the IPC server answering every
  query with the reload string at exit 0 for minutes.
- **The wallpaper picker showed `0/0` on every fresh load.**
  `resolveTheme()` assigns `currentName` but every `rebuildPickerModel()`
  call site fires while it is still `""`, so `wallpaperRows()` looked up
  `presets[""]`. The model now follows the name.
- **A "Dark Mode Base" toggle that did nothing** — it wrote
  `Theme.darkMode`, which is `readonly` and derived from the palette, and
  no palette is light. Removed rather than given an override for a
  palette that does not exist.
- **Per-monitor bar overrides were shared between screens.**
  `BarConfigMonitors` was a singleton with mutable state and one Island
  per screen wrote to it. Worse than last-writer-wins: once a second
  instance asked, *no* override applied at all. Now a per-monitor
  `QtObject` with `screenName` as a `required property` — there is no
  writer left to race.
- **The settings window had ~270px of dead space**, and the control
  centre ~370px, both from hand-kept heights that had drifted. Both now
  derive from content and are clamped to the Island's own screen. Same
  bug class `todos.md` Phase 3 records for the bar window.

### Tooling

- `scripts/lint.sh` resolves a real **Qt6** `qmllint` (the `/usr/bin`
  one here is the Qt 5 stub, which analyses nothing and emits an empty
  log), asserts the log is non-empty, checks every `Quickshell.*` import
  against the installed binary, and gained `service-missing-import`.
- `tests/run.sh` 15 → 18 checks: theme tokens (every `Theme.colors` key
  exists in all six palettes; all palettes share one key set), a bounded
  clipboard reply, and a reload-gap retry that keys on the exact string
  Quickshell returns mid-reload.
- `quickshell/scripts/shell-log.sh`, because `journalctl --user` is a
  **dead channel** for this shell: fd 1 and fd 2 are `/dev/null`. `errors`
  exits 3 when it matches nothing, so a log check cannot silently pass.

### Verification status for this round

`./scripts/lint.sh` clean. `./tests/run.sh` 18/18, three consecutive
runs. `check-ipc-table.py` 93 functions across 15 targets. `ipc-audit.py`
clean. The tree loads clean in a fresh instance, and Bluetooth, the
colour change, the geometry change, the per-monitor fix and the
clipboard bound were each confirmed against the running desktop —
screenshots, not inference.

**Not verified, and not claimed:** multi-monitor (one output on this
machine), light mode (no palette exists), `AuthDialog` rendered live (no
polkit request was faked), D-Bus ingest to a second notification server
(the live shell holds the bus name), and every keyboard, hover and
pressed path. `ControlCenterLayout.settle` does not always terminate —
pre-existing, preserved through the split, still open. `log.qslog` grows
~2.6 MiB/day of NetworkManager property spam.

## Round 12 — three floating surfaces become one morphing island

The bar was three separate pills: `IslandCenterPanel` (the notch, and
every surface that opened in it) with `IslandLeftDot` (album art /
media player) and `IslandRightDot` (battery + wifi / control centre)
hanging off its measured edges. That is now **one `Surface`**
(`surfaces/IslandPanel.qml`), and the two dots are gone.

What made it possible was that the rest state had been *two* things
already — a resting pill and a wide panel — but they had never been
the same object. `IslandHomeFace.qml` lays out both from one set of
declarations: the workspace bars, the clock and the status indicators
are written once and just sit at a different `y`. Two faces would have
had to agree on all three by hand, forever.

### The numbers are measured, not invented

Reference screenshots of the same shell at a different scale factor
(`K = 1.8`, verified three ways against live geometry) were measured
pixel by pixel and divided through. The result, at logical size:

- rest pill ≈ **195×30** (for five workspaces; `n*6 + (n-1)*4` bars),
  stadium radius, 16px pad, clock at 14 DemiBold centred;
- wide panel ≈ **368×76**, clock + date at `y12`, workspace name at
  `y30`, bars at `y46`, a 156×30 now-playing card centred at `y33`,
  status vertically centred and pinned to the right pad.

Live check: the pill centres on 959.5 against a screen centre of 960,
stands 29px for a `barHeight` of 29.55, and grows to 199 when a fifth
workspace exists. The wide panel measures 357 against 368 predicted —
the difference is the workspace count, not the layout.

### One `MouseArea`, declared last, and why that is not a style choice

Two overlapping `MouseArea`s do **not** hand a press down to the one
underneath: a press the top area does not accept walks up the *parent*
chain and is discarded, it never reaches a sibling. So a hover area on
top and a click area below it would have produced a pill that widens
when you point at it and does nothing when you click it.

There is therefore exactly one `MouseArea` in `IslandHomeFace.qml`, and
it is the last child — which is also what makes the hover work, since
the scene returns the topmost item under the cursor. It routes the
click by hit-testing against the zones it covers (status → control
centre, card → media, bars → `Workspaces.focus`, everything else →
calendar), which is why `WorkspaceBars` exposes `indexAt(x)` instead of
carrying a `MouseArea` per bar: one inside it would sit underneath the
face's area and never see a press.

### The workspace indicator needed compositor data, so it got a service

Nothing in the tree read `Hyprland.workspaces` yet, and the bars need
it: which workspaces exist, which one is focused, and a way to switch.
`services/Workspaces.qml` is the singleton that does those three
things, and it is now the second file importing `Quickshell.Hyprland`
(`Compositor.qml` was previously the only one — its comment said so,
and has been corrected rather than left to rot). Its `items` filters
`special` workspaces out but keeps named ones, and the per-screen
filter is deliberately permissive: a workspace whose monitor we cannot
name is shown rather than dropped, because a missing bar reads as a bug
and a redundant one does not.

### Settings that lost their consumer, and one that found a new one

- **`stageLiftOnHover` is gone.** Its only two readers were the two
  dots, and the thing it did — lift on hover — is now the island
  widening on hover, which supersedes it. A slider that moves nothing
  is worse than no slider.
- **`innerPadding` is now the now-playing card's inner padding.** It
  was the album-art dot's padding; the dot is gone. At its default of
  3 it lands the artwork inset, the text origin and the dots' right
  margin at 5 / 35 / 7 — within a pixel of the measured reference, so
  the default did not need to move.
- **"Collapsed width" is relabelled "Minimum island width"**, because
  that is what it became: the face now sizes itself from its own
  content, so the slider is a floor, not the width. It still does real
  work — it is what heals a persisted `collapsedWidth: 97`.
- The two toggles were renamed to what they actually gate: "Status
  indicators (signal and battery)" and "Now-playing card".

### Checked, and deliberately not done

`decoration:glow` in the Hyprland config was considered and skipped:
it is a *window* decoration and is not rendered on layer-shell
surfaces, so it would have done nothing to the bar. `Surface.qml`'s
stacked-rectangle shadow remains the mechanism.

The OSD semantics are unchanged on purpose: `isOsd` still comes first
in `targetW`/`targetH`, so it keeps its own 275×43 pill and its `z:
100`. The consequence — media and the control centre now morph through
that pill instead of sitting beside it — is the single-island rule
applied consistently rather than an exception for two surfaces.

`scripts/lint.sh` clean, `tests/run.sh` 18/18, and the collapsed,
wide, control-centre, media and calendar states were each captured and
measured against the reference.

## Round 13 — three surfaces measured against the screenshots they were drawn from

Round 12 measured the island. Carrying on through the rest of the same
ten reference screenshots turned up three surfaces whose geometry did
not survive the same measurement: the control centre, the power menu
and the wallpaper picker. The numbers below are what a pixel probe
returns, not what the tokens claim.

Two things about the references change how the comparisons have to be
read:

- They come in two groups. The `11-42-*` and `11-43-*` shots are the
  teal theme at `K = 1.8`; `11-44-*`, `11-45-58` and `11-46-17` are a
  blue-wallpaper session at `K ≈ 1`. A teal reference has to be divided
  through before it means anything; a blue one compares directly. The
  power-menu and wallpaper-picker numbers below are the `K = 1` pair.
- The panels sit on photographic wallpaper, and their shadows bleed
  into any bounding-box probe. The numbers that held up are the ones
  measured from *content* — tiles, text ink, thumbnail edges — with the
  panel edge taken only where the wallpaper behind it is dark enough
  for the edge to be sharp. Reading the panel edge directly off
  `11-46-17` gave four different answers in four attempts; overlaying a
  coordinate grid and measuring the tiles gave one, and the tiles are
  what the fix is expressed in anyway.

### Control centre: 45px of black below the last row

`panelHeight`'s home branch was a literal `514` — the kind of number
that is right once and then stays right while everything under it
moves. Against the reference it produced a band of empty black roughly
45px deep below the final row, a fifth of the panel.

It is now `Math.ceil(homePage.contentBottom + 28)`, where
`contentBottom` walks `layoutItems` and takes the maximum of
`rowTop(it.row) + rowHeightFor(it)`. It cannot be written as "the
bottom of `rowTops`": `rowTops` pushes `y` *before* it checks whether
the row has anything in it, so a trailing empty row leaves a phantom
entry and the height jumps straight back to where it was. That is also
why `contentBottom` exists as a separate property rather than fixing
`rowTops` — the map is read elsewhere for exactly the keys it does
have.

The panel went from 509 tall to **478** (`y6..483`), content bottom
470, bottom padding **13** against the reference's 14, with all five
content bands present. Width unchanged at 459, centred on 960.0.

### Power menu: 20px of inset where the reference has 14, tiles 20px too narrow

Reference `11-46-17`: panel **511×108**, five tiles **90×80**, gap 8,
content span 483, ~14px of panel on every side. Live was **422×121**
with **70×81** tiles and a content span of 382 — the tiles were 20px
narrow each and the inset was 20 rather than 14.

The inset was never `containerPadding` alone: `IslandPanel` gives
every surface `anchors.margins: 12` and adds the matching `+24` to
`targetW`/`targetH`, so what the eye sees is `containerPadding + 12`.
Eight plus twelve is twenty, and no amount of adjusting one side alone
reaches fourteen.

- `tileWidth: 70 → 90`
- `containerPadding: 8 → 2` (2 + 12 = 14)

The panel is now ≈ **512×110**, tiles 5×90 with gaps of 8, content span
482 against the reference's 483, inset 15/16 against its 13/15. The
button height and gap had always matched — `tileHeight: 81` against a
measured 80 was left alone, it is inside the measurement error.

### Wallpaper picker: a wrapper margin the reference does not have

Reference `11-45-58`: panel **1000×238**, title and footer sitting
**15** in from the left edge, thumbnail strip 115 tall, gaps of 24 and
29 between the three rows, title ink 17 rows tall. Live was
**1032×246** with content **28** in from the edge.

Twenty-eight is not an accident of padding: it is the picker's own
`anchors.margins: 16` with `IslandPanel`'s `+24`/`topMargin: 12`
wrapped around it. The reference's 15 *is* the 16 — the panel is the
picker, with no wrapper at all. The 32px of extra width was exactly the
wrapper. So the wallpaper picker became the one surface that opts out
of the `+24`:

- `targetW`/`targetH` drop the `+24`, and `anchors.topMargin: 12` goes
  with it;
- `width: 1008 → 1000`, `implicitHeight: 222 → 238` — with the wrapper
  gone these *are* the panel, which is the point;
- `spacing: 12 → 16`, because 12 produced row gaps of 22 and 23 where
  the reference has 24 and 29;
- title `font.pixelSize: 15 → 17`, because the reference's "Wallpaper"
  ink runs 17 rows tall and 15 produced 15.

Measured after: panel **999×237** against 1000×238, left inset **15**
against 15, thumbnail strip 114 against 115, footer ink 11 against 11,
bottom padding 18 against 20, top padding 21 against 23. The one
residual is the gap above the thumbnail strip — 30 against 24 — which
is the title sitting two rows higher than the reference's rather than
anything wrong with the strip.

### Reported, not applied: the control centre's row heights

The reference's control-centre rows are uniform — 54.0, 54.2, 53.9,
53.7, pitch ≈63.2. Live runs 57, 57, 52, 52 at pitch 70, 70, 62, 62,
which is **+11px** of the residual height difference and the last
piece of it after the fix above. It is not a one-line change: the
heights live in a table duplicated between `CcHomePage.qml` and
`CcControl.qml`, and `CcControl` keys a shape off it
(`isDisc: cellHeight === 60`), so moving the tokens moves which cells
are drawn as discs. It needs doing as one change across both files
with the control centre captured before and after; it was measured and
left rather than half-applied.

`scripts/lint.sh` clean (4973 pre-existing warnings, unchanged),
`tests/run.sh` 18/18. All three surfaces were captured live with
`grim` and probed with PIL against their reference images — the probes
lived in `/tmp` and are not part of the repo.

## Round 14 — the theme picker's inset, Escape's missing last step, and an island that would not collapse

### Theme picker: the same wrapper margin, counted differently

Reference `11-43-43` (teal group, 805×221 crop): panel **804×221**,
search field and footer sitting **17/15** in from the left and right
edges, card row 68..166, footer ink 194..204, bottom pad 17.

Live measured **802×218** — the panel was already right, and it had to
be: `targetW`/`targetH` add the standard `+24` and the picker is
centred inside it, so 780+24 is the 804 the reference shows. What was
wrong was the inset: **27/26** against 17/15.

That 11px is not padding gone astray. `IslandPanel` centres the picker
in a panel 24 wider than it, so 12 of inset is already applied outside
the surface, and the picker's own `anchors.margins: 16` sat on top of
it: 12 + 16 = 28. The reference's 16 is the *visible* inset, so the
picker's share of it is 4. Unlike the wallpaper picker — where removing
the wrapper was the fix because the reference had no wrapper at all —
here the wrapper is correct and only the inner number was wrong, so
this is one line:

- `anchors.margins: 16 → 4`

Measured after: inset **17/16** against 17/15, card row 66..162 against
68..166, footer ink 191..201 against 194..204, bottom pad **17 against
17**. The one residual is the search row's ink sitting ~7px lower than
the reference's while every band below it matches — the reference's
placeholder text is visibly larger than live's, which points at the
teal theme's font metrics rather than the layout.

### Escape closed everything except the one surface that most needed it

Testing all nine surfaces with `wtype -k Escape` (the bar window
already takes `WlrKeyboardFocus.Exclusive` while `UiState.anyOpen`, so
keys reach it): power menu, settings, launcher, clipboard, calendar,
media, theme picker and wallpaper picker all closed. The control centre
did not — Escape from the control centre did nothing, forever.

The cause was one line:

```qml
Keys.onEscapePressed: root.view = "home"
```

That handler accepts the event unconditionally, so on a drill page it
navigated home, and on the home view it assigned `"home"` to a value
that already was `"home"` and swallowed the key. Either way the event
never travelled up to `Island`, which owns `UiState.closeAll()` — so
the control centre was the one surface Escape could not dismiss.

It is now a back stack with a real last step:

- a modal open (the Wi-Fi password dialog) → cancel it;
- a drill page open → go home;
- home → `event.accepted = false`, which lets the key keep bubbling to
  `Island` and close.

Verified with `quickshell log`: the close is attributed to
`closeAll ← onEscapePressed@Island.qml:74`, and the drill case stays
open after the first Escape.

Two false leads are worth recording because they cost time. First, an
earlier run reported the control centre closing *after one* Escape in
the drill view — a stack trace on `UiState.mode` showed the close came
from `onClicked@shell.qml:203`, i.e. a real click on the backdrop, not
from the key. Second, the same trace caught
`toggleCalendar ← IslandHomeFace.qml:344`, a click routed by the
island's own MouseArea. Without the stack it was impossible to tell a
stray click from an Escape that went to the wrong place, which is why
the trace existed for exactly two runs and is not in the tree now.

### The island would not collapse, and "playing" was not the answer either

Reported as a stuck hover. The pointer was at (1616,561) — nowhere near
the island — and the panel measured **354** wide against a 186 rest.

Hover was not the problem: disabling only the media branch of `rich`
collapsed it to the rest pill, which proves `zone.containsMouse` was
false all along. The media branch was:

```qml
rich: hovered || (Media.hasPlayer && BarConfig.albumArtCircleEnabled)
```

`Media.hasPlayer` is "some player is registered", and `Media.pickBest()`
falls through to `players[players.length - 1]`, so a Firefox tab
holding a **paused** video (`100xDevs Learner Account`, 6989s, `Paused`)
counted as an active track and pinned the panel wide for an hour.

Narrowing it to `Media.playing` fixed the paused case and was then
reported as still wrong — Brave's background music reopened it, which
is the same panel that will not go away by a different route. So the
second trigger is removed rather than narrowed a third time:

- `rich: hovered || (…)` → `rich: hovered`

`albumArtCircleEnabled` still gates whether the card is *drawn*
(`showCard`); what it no longer does is decide the bar is open. The
card is one hover from reach either way.

Measured after: **176** at rest with Brave `Playing` and the cursor at
(628, 398).

`scripts/lint.sh` clean (4973 pre-existing warnings, unchanged),
`tests/run.sh` 18/18.
