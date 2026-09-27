# Quickshell desktop config

A Hyprland + Quickshell shell: notch/pill bar (`Island.qml`), control
center, settings app, launcher, power menu, lock screen, and a static
theme+wallpaper system shared with Hyprland itself. Built and
tested against **Quickshell 0.3.1**.

For "what was actually broken and how it got fixed," see
`CHANGELOG.md`. For "how the pieces fit together and the sharp edges
to know about," see `ARCHITECTURE.md`. This file is just: what you
need installed, how to get it running, and what to expect once it's up.

## Requirements

This was built and is used on **Fedora**. Package names below are
`dnf`; adjust for your distro.

| Needs | Why | Fedora |
|---|---|---|
| Hyprland (+ `hyprlock`, `hypridle`, `hyprpaper`) | compositor + lock/idle/wallpaper daemons | **not in Fedora's official repos.** Needs a COPR — `solopasha/hyprland` is the long-standing community one; a few newer ones exist too (e.g. `ashbuk/Hyprland-Fedora`). Check what's current before installing, this changes. |
| Quickshell **0.3.1** | the shell itself | **also not official.** COPR/AUR/source build only. The sharp edge: Quickshell's COPR builds are pinned to a specific Qt6 minor version, and Fedora's shipped Qt6 moves faster — a Quickshell build against Qt 6.9 will refuse to run against a system on 6.10+. Match versions before filing a "shell won't start" bug against this config. |
| Qt6 (Declarative/QML, at minimum) | Quickshell runs on it | `qt6-qtdeclarative`, `qt6-qtquickcontrols2`, `qt6-qt5compat` is **not** needed — see the note below |
| Kitty | terminal (**not** theme-integrated — see Theming) | `kitty` |
| Python 3 | powers `quickshell/scripts/*.py` (theme discovery, publish-colors, list-apps, polkit agent, inotify-watch) | `python3` |
| `cliphist` + `wl-clipboard` | clipboard history | `cliphist`, `wl-clipboard` |
| `polkit` | auth prompts (`Auth.qml` wraps `Quickshell.Services.Polkit`) | `polkit` |
| `inotify-tools` | live theme-file watching (optional — degrades to poll-on-open if missing, doesn't crash) | `inotify-tools` |

**About `qt6-5compat`:** earlier versions of this config used
`Qt5Compat.GraphicalEffects` and it crashed on first run because that
package wasn't installed. It's since been removed from the codebase
entirely (see CHANGELOG Round 1 and Round 9) in favor of native
`clip: true` masking and `QtQuick.Effects.MultiEffect` — so you do
**not** need `qt6-5compat`. You do need `QtQuick.Effects`
(`qt6-qtdeclarative` on Fedora covers this).

## Installing

```sh
git clone <this-repo> && cd <this-repo>
./install.sh
```

This symlinks `colors/`, `hypr/`, `kitty/`, `quickshell/`, `vlc/`, and
`Thunar/` into `~/.config/`, backing up anything already there, and
prints which runtime deps from the table above are missing on the
current machine. It does **not** install packages for you — Hyprland
and Quickshell both need a COPR or source build picked deliberately
(see table), not a blind `dnf install`.

Then: log into a Hyprland session, and `quickshell` starts via
`hypr/modules/startup.lua`. To run it standalone for debugging:

```sh
qs -c quickshell
```

## What currently works

- Bar/notch/island with media pill, clock, battery ring, Wi-Fi status
- Control Center: Wi-Fi (scan, connect, **password-protected networks
  now actually work** — see CHANGELOG Round 9), Bluetooth, Sound,
  Display (per-monitor brightness/scale/resolution), notifications,
  DND
- Settings app — 11 pages: Bar & Island, Display, Clock & Date,
  Appearance, Motion, Launcher, Notifications, Media, Control Center,
  Lock Screen, System
- Theme system — `colors/themes/<name>/colors.json` is the single
  source of truth: **static, hand-authored palettes, no generator and no
  wallpaper sampling**; wallpapers are generated *from* each theme's
  palette (`scripts/generate-theme-wallpapers.py`), never the other way
  around. Hyprland border colors follow the active theme both live (on
  switch) and after a reboot (seeded from the generated
  `colors/hyprland.conf` at config-load time). Kitty is deliberately
  **not** themed — it stays on its own defaults.
- App launcher, power menu, lock screen

## Theming

Colours are static. There is no per-wallpaper extraction step and no
cache to go stale: whichever theme is active, its
`colors/themes/<name>/colors.json` *is* the palette, both in-shell and
on disk. To change theme, either use the UI (island theme picker) or
edit config — no code changes either way.

**In the shell** (applies immediately, publishes to the desktop):

```sh
qs -p ~/.config/quickshell ipc call theme set gruvbox   # by name
qs -p ~/.config/quickshell ipc call theme cycle         # next theme
qs -p ~/.config/quickshell ipc call theme list          # available names
```

The choice is saved to
`~/.config/quickshell/shell-state/theme-state.json` and wins over
`index.json` on the next start.

**By editing config** — set the active theme in
`colors/index.json` (this is the knob `list-themes.py` and
`publish-colors.py` read):

```sh
# current: the active theme. default: what a fresh install picks.
$EDITOR ~/.config/colors/index.json
```

The shell picks up a changed `index.json` live (it watches the file);
if a saved `theme-state.json` exists, delete the `theme` key from it or
remove the file to let `current` take effect on next start.

**Publishing only**, without the shell — handy from a Hyprland
`exec-once` or a manual test. `publish-colors.py` resolves the theme
first-wins: CLI argument, then `$QUICKSHELL_THEME`, then `current` in
`index.json`, then `everforest`.

```sh
python3 quickshell/scripts/publish-colors.py gruvbox          # explicit
QUICKSHELL_THEME=horizon python3 quickshell/scripts/publish-colors.py
python3 quickshell/scripts/publish-colors.py                  # from index.json
qs -p ~/.config/quickshell ipc call theme publish gruvbox     # same, from a running shell
```

It writes `colors/{current.json,colors.css,colors.sh,hyprland.conf,gtk.css,kitty.conf}`
and pushes Hyprland's active/inactive border colors live. Editing a
theme's `colors.json` re-renders the shell (it's watched) but does
**not** re-publish to the desktop — use `theme publish <name>` for that.

To author a new theme: drop a `colors/themes/<name>/colors.json` with
at least `background`, `surface`, `surfaceAlt`, `foreground`, `accent`,
`accentText`, `error`, `warning`, `success`, add the key to `themes` in
`index.json` with a `wallpaperDir`, and it shows up in the picker
immediately. Missing keys fall back to the built-in defaults rather
than breaking.

## Known gaps

- **~300 `qmllint` "unqualified access" warnings** across ~30 files —
  the legacy implicit-context-property lookup pattern inside
  delegates/`Connections` blocks. This still works (Qt fully supports
  it), it's just superseded by `pragma ComponentBehavior: Bound` +
  `required property`. Not a bug, just not modernized everywhere yet.
  `SettingsApp.qml`'s nav delegate was converted as a template for
  doing the rest.
- No visual regression testing — every fix in the CHANGELOG was
  verified by static audit (reading the actual Quickshell/service
  source, cross-checking property and function names) or by a real
  crash report, not by a screenshot diff. If something *looks* wrong
  after an update, it might be a fresh bug this process can't catch.
