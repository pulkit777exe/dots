# Simplification review — reading ChillPill-Shell

> **Status: acted on, and partly wrong.** This review is what motivated
> `services/Bluetooth.qml`'s rewrite onto `Quickshell.Bluetooth`, which
> is now done and verified. Three of its claims were later **disproved**
> by running the real module against the live BlueZ on this machine, and
> are marked **[SUPERSEDED]** inline with what is actually true instead.
> Everything unmarked still stands. Kept as the record of why the
> rewrite happened — not as current-state documentation. For what is
> true now, see `ARCHITECTURE.md`'s event-driven section.

Written after reading [LUCKYS1NGHH/ChillPill-Shell](https://github.com/LUCKYS1NGHH/ChillPill-Shell)
(a Quickshell/Hyprland pill bar, built for machines without a discrete GPU), because
the question on the table was whether this codebase is more complicated than it needs
to be. It is — and most of the reason is visible by comparing one file.

## What was read

| File | Lines | Bytes |
|---|---|---|
| `qml/Bluetooth.qml` | 65 | 2 197 |
| `qml/BluetoothPanel.qml` | 338 | 12 271 |
| `qml/Notifications.qml` | 38 | 422 |
| `qml/Theme.qml` | 97 | 2 063 |
| `qml/Battery.qml` | 32 | 804 |
| `config-app/shell.qml` | — | 74 756 |
| `qml/shell.qml` | — | 47 247 |

44 QML files, 352 KB total. Their two `shell.qml` files are large, so they have not
solved complexity by refusing to have any — they concentrated theirs in the entry
point and kept the services tiny.

## Finding 1 — the stock Quickshell Bluetooth API is already on this machine

This is the important one. Their entire Bluetooth service is a pure view:

```qml
readonly property bool btEnabled: BluetoothController.enabled
Repeater {
    model: BluetoothController.enabled ? BluetoothController.devices : null
    BluetoothController.pairDevice(address) / connectDevice / disconnectDevice / forgetDevice
}
```

> **One clarification, since the code block invites the wrong reading.**
> `BluetoothController.pairDevice` / `connectDevice` / `disconnectDevice` /
> `forgetDevice` are **`IslandBackend`'s own wrapper methods**, not
> methods on a stock Quickshell type. The stock `BluetoothAdapter` has
> **no callable QML methods at all** — see the API listing below. Do not
> read this block as an inventory of what `Quickshell.Bluetooth` offers.

No `Process`, no polling, no output parsing. It is not their invention —
`BluetoothController` comes from `IslandBackend` (the README credits enhaoswen for
the Wi-Fi backend), but the underlying API is **stock Quickshell**, and the installed
binary here already has it:

```
$ strings /usr/bin/quickshell | grep -E '^Quickshell\.[A-Za-z.]+$'
Quickshell.Bluetooth        ← this one
Quickshell.Networking
Quickshell.Services.Mpris / Notifications / Pam / Pipewire / Polkit / SystemTray / UPower
Quickshell.Hyprland / Io / Wayland / Widgets / WindowManager
```

`import Quickshell.Bluetooth` gives a `Bluetooth` singleton with `adapters`,
`devices` and `defaultAdapter`; a `BluetoothAdapter` with `enabled`, `discovering`,
`discoverable`, `pairable`, `name`, `adapterId`, `state` and a
`devices : ObjectModel<BluetoothDevice>`; and `BluetoothDevice` objects carrying
`address`, `name`, `deviceName`, `paired`, `bonded`, `trusted`, `connected`,
`state`, `pairing`, `battery`, `icon`, with methods `connect()`, `disconnect()`,
`pair()`, `forget()`, `cancelPair()`.

> **[ADDED AFTER VERIFICATION] A `BluetoothAdapter` has no callable QML
> methods.** Every one of the names above is a *property*; the type
> exposes nothing you can invoke. Adapter power and discovery are
> therefore **property writes**, not calls:
>
> ```qml
> adapter.enabled = !adapter.enabled;   // not adapter.setEnabled(...) / adapter.toggle()
> adapter.discovering = true;          // not adapter.startDiscovery()
> ```
>
> This is the one part of the listing above that the original review
> left implicit, and it is the part that decides whether a rewrite works
> on the first try. The device-level methods (`connect()`, `disconnect()`,
> `pair()`, `forget()`) *do* exist and are what the shipped
> `services/Bluetooth.qml` calls. Confirmed against Quickshell 0.3.1 by
> exercising the module against the live BlueZ, not from docs.

So every value this repo hand-parses out of `bluetoothctl` text exists as a bindable
QML property:

| this repo, scraped from `bluetoothctl` | stock API |
|---|---|
| `powered: yes` from `bluetoothctl show` | `adapter.enabled` |
| `Discovering: yes` | `adapter.discovering` |
| `bluetoothctl devices` + `devices Connected` + `---` splitting | `adapter.devices` (ObjectModel) |
| `paired: true` hardcoded for every parsed row | `device.paired` / `bonded` / `trusted` |
| `isConn` from a second command | `device.connected` |
| — | `device.state`, `device.battery`, `device.icon`, `device.signalStrength` |

A public Quickshell config does the same in **22 lines**:

```qml
Singleton {
    readonly property BluetoothAdapter defaultAdapter: Bluetooth.defaultAdapter
    readonly property list<BluetoothDevice> devices: defaultAdapter?.devices?.values ?? []
    readonly property BluetoothDevice activeDevice: devices.find(d => d.connected) ?? null
}
```

**What this repo paid for the privilege of scraping instead** — the
"before" column is this repo as it stood when this review was written; the
"after" column is `services/Bluetooth.qml` today:

| | before | after |
|---|---|---|
| `services/Bluetooth.qml` | 8 801 bytes | 166 lines, 0 subprocesses |
| processes | 8 (`bluetoothctl` poll spawns 3 per cycle, plus toggle/scan/connect/disconnect/pair/forget) | 0 — nothing is spawned, so there is nothing to reap |
| text parsed | `show`, `info`, `devices`, a readline REPL with ANSI stripping | none |
| `recovery.sh` reap entries | 3 (one of which named a process that never existed) | 2 |

And the cost was not hypothetical — it caused both bugs fixed by the
rewrite:

1. **Discovery never worked.** `bluetoothctl devices` reads BlueZ's *cache* (paired
   hardware), so `devices.filter(d => !d.paired)` could never match, and a `scan on`
   whose output was thrown away gave a stranger device nowhere to appear. Fixing it
   meant parsing a readline REPL: `bluetoothctl --agent NoInputNoOutput`, stripping
   ANSI colour and cursor escapes and CRs, dropping the prompt, and matching
   unanchored because a prompt on the front means `^` never fires.
2. **A permanent `bluetoothctl` process** that `recovery.sh` then had to learn about,
   because the reap list still named `bluetoothctl monitor` — a process that never
   existed, which is why the documented design and the code had drifted apart for so
   long.

With the native API both are properties instead of parsing problems, and the whole
service collapses to roughly what theirs is.

**Done.** `services/Bluetooth.qml` is 166 lines and spawns nothing. The
process count, the byte count, the parser and the `recovery.sh` special
case in the table above are all historical.

## Finding 2 — services and views are separate files

Their `Notifications.qml` is 38 lines of `Text` showing a count. The logic lives in
`NotificationModule.qml` (3.5 KB) and `NotificationStack.qml` (7.6 KB).

This repo's `services/Notifications.qml` is 20 266 bytes and is four things at once:
the notification daemon state, the `notify()` formatter, ten `Connections` blocks,
and two `IpcHandler`s. That is why the six duplicated guard blocks were so hard to see
as one thing.

> **Partly acted on — and the line count barely moved.** What changed was
> the *duplication*, not the structure: the six `Connections` blocks that
> each carried a hand-rolled `property bool initialised` +
> `property <T> wasX` + a `wasX !== X` re-check now share one idiom — a
> single `property bool seenStartupChange` that swallows the first
> change and then trusts the handler's own value. A 3-second
> `systemNotifsReady` `Timer` that only gated one of the six went with it.
>
> **The file was not split.** It is still 952 lines (down from 1 056),
> still 10 `Connections`, still 2 `IpcHandler`s, still all four jobs.
> `git diff --numstat` on that change reads 102 insertions against 206
> deletions with every hunk a pure deletion plus its replacement — a
> net line count that looks like an extraction but is not one. Splitting
> it is a separate, larger change and was deliberately left alone. Do not
> read the -104 lines as progress toward Finding 2; the duplicated guard
> idiom is gone, the four-way split is not started.

## Finding 3 — one config singleton, no theme machinery

Their `Theme.qml` is 97 lines of flat literals (`bg`…`bg9`, `fg`…`fgL`, a few
accents). This repo's is 16 495 bytes: presets, per-theme wallpaper state, a
persisted index, a picker, `publish()`.

That is a **product** difference, not a technique difference — a theme picker with
per-theme wallpaper state is a feature, not bloat. Worth noting only so the size
comparison is not mistaken for the same job done badly.

## What I would change here, ranked

1. ~~**Rewrite `services/Bluetooth.qml` on `Quickshell.Bluetooth`.** Biggest single
   win available: ~8.8 KB and 8 processes → a few dozen lines and zero processes.
   Removes the poll, the parser, the REPL escape-stripping, the discovery window
   logic, and the `recovery.sh` special case.~~ **DONE** — 166 lines, zero
   subprocesses, verified against the live BlueZ. See `ARCHITECTURE.md`.
2. **Split `services/Notifications.qml`** into service / notify-formatting / watchers.
   **NOT DONE, deliberately.** The duplicated guard blocks were collapsed (see
   Finding 2) but the file was not split: that is a bigger change than the
   duplication was worth doing in the same pass, and it is still open.
3. Leave `Theme.qml` and `ControlCenter.qml` alone on scope grounds — they are big
   because of features, not because of duplication (the duplicate-block scan across
   all 83 files found nothing worth consolidating). *Partly overtaken:* while
   rewriting `ControlCenter.qml`'s cell bodies the eleven-sibling-with-`visible:`
   pattern turned out to be a real cost (ten of eleven children were built and
   hidden per cell), so those bodies are now behind one `Loader` with a
   `sourceComponent` switch. That is a construction fix, not a split.

## Caveats — what is *not* verified

> **This whole list was written before the work and three items in it are
> wrong.** Each is corrected inline below. They are kept rather than
> deleted because "this check was made and it was wrong" is the useful
> part.

- ~~**No live import test yet.** The module URI and the property names are confirmed
  present in the binary and in the 0.2/0.3 docs, but `qmllint` on a probe file
  importing `Quickshell.Bluetooth` was inconclusive, and the rewrite should not start
  until a trivial `Component.onCompleted` probe confirms the type resolves in the
  installed version.~~
  **[SATISFIED — and the caveat about `qmllint` was itself the problem.]**
  The module resolves, the properties bind, and the service is running
  against real BlueZ now. Separately: `qmllint` could never have answered
  this question. It exits 0 with an *empty log* on a file importing a
  module it cannot resolve, so an inconclusive probe here meant the tool
  was silent, not that the answer was unknown. `scripts/lint.sh` now
  asserts the log is non-empty and cross-checks the tree's `Quickshell.*`
  imports against `strings /usr/bin/quickshell`.
- ~~**The adapter on this machine is wedged** (`bluetoothctl info hci0` → "not
  available" while `show` claims `Powered: yes`; `scan off` →
  `org.bluez.Error.Failed`), so no runtime data can be read until
  `sudo modprobe -r btusb && sudo modprobe btusb`. Discovery cannot be verified
  end-to-end on this machine right now.~~
  **[SUPERSEDED — discovery *was* verified here.]** The adapter came back
  after a reload; it was the `bluetoothctl` path, not the hardware, that
  was broken. With scanning on, an unpaired device was observed reaching
  `nearbyDevices` through the module. That observation is what made the
  `discovered`-list removal safe: the object manager reports a device the
  moment it is seen, paired or not, so there is no separate list to keep.
- ~~**Pairing agents.** Stock Quickshell registers its own D-Bus agent at
  `/quickshell/agent`. Anything relying on a PIN/passkey prompt needs checking
  against this repo's existing `Auth.qml` polkit flow before the old
  `bluetoothctl pair` path is deleted.~~
  **[SUPERSEDED — the premise is false, and the concern was misplaced.]**
  Quickshell 0.3.1 registers **no `org.bluez.Agent1` at all**:
  `strings /usr/bin/quickshell | grep -ci agent1` → `0`, and there are no
  `RequestPinCode` / `RequestPasskey` symbols either. PIN and passkey
  prompts therefore cannot be answered from QML.
  **This is not a regression.** The old `bluetoothctl pair` ran as a
  detached `Process` with piped stdio and no terminal, so it could not
  answer one either. A device that only needs a confirmation on its own
  side — the common case — pairs through the module unchanged.
  And `Auth.qml` was the wrong thing to check: polkit authenticates an
  *action* against a privileged service, while a pairing agent is a plain
  session-bus client answering BlueZ's method calls. Same word, unrelated
  mechanisms.
- `IslandBackend`'s `BluetoothController` is a third-party module; the *stock*
  `Quickshell.Bluetooth` API is what is installed here, and it is the smaller target.
  **Still true**, and the rewrite went that way.