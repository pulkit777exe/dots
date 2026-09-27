# Quickshell desktop config

A Hyprland + Quickshell shell: notch/pill bar (`Island.qml`), control
center, settings app, launcher, power menu, lock screen, and a
theme+wallpaper system shared with Kitty and Hyprland itself. Built and
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
| Kitty | terminal, theme-integrated | `kitty` |
| Python 3 | powers `quickshell/scripts/*.py` (theme generation, publish-colors, list-themes, polkit agent, inotify-watch) | `python3` |
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
  source of truth; wallpapers are generated *from* each theme's
  palette (`scripts/generate-theme-wallpapers.py`), never the other
  way around; Kitty and Hyprland border colors follow the active
  theme both live (on switch) and after a reboot (seeded from the
  generated `colors/hyprland.conf` / `kitty/current-theme.conf` at
  config-load time)
- App launcher, power menu, lock screen

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
