# dots

A Hyprland + Quickshell desktop environment for Fedora, kept as one
reproducible repo. The compositor config is Lua; the shell (island bar,
launcher, control centre, settings, theme and wallpaper pickers, power menu,
notification toasts) is Quickshell/QML; everything colour-related is
generated from a single palette per theme.

## Install

Fresh Fedora machine — packages first, then configs:

```bash
git clone https://github.com/pulkit777exe/dots.git ~/dots
~/dots/dots packages --all    # dnf packages, drivers, shell tooling (no link yet)
~/dots/dots link              # symlink configs into ~/.config + ~/.zshrc
~/dots/dots apps              # brave + flatpak apps (needs a terminal for sudo)
```

`dots packages` provisions per group (`--desktop`, `--shell`, `--session`,
`--nvidia`, `--dev`; default is desktop + shell + session, `--all` is
everything). `dots link` / `dots check` / `dots fonts` / `dots session` /
`dots update` run the matching step. It never runs as root — `sudo` is used
per `dnf` command only — and it skips anything already present. NVIDIA
(`--nvidia`) needs a reboot afterwards, and Secure Boot needs the akmods key
enrolled once (the script prints the exact command when it applies).

On Fedora Server (or any install without a login screen): the default
`multi-user` target boots to a TTY, so there is no Hyprland session to pick.
The `--session` group (on by default) installs `sddm` + `uwsm`, sets the
`graphical` target and enables `sddm`, so a reboot lands on a login screen.
`install.sh --check` verifies all of it: default target, an enabled display
manager, a wayland-session file, `uwsm check may-start`, and the `python3`
`xdg` module uwsm needs.

Configs only (packages already handled):

```bash
curl -fsSL https://raw.githubusercontent.com/pulkit777exe/dots/main/bootstrap.sh | bash
```

That clones the repo to `~/dots` and runs `install.sh`, which symlinks every
config unit into `~/.config`. Anything already there is **moved aside**, never
deleted.

Already have a clone?

```bash
git clone https://github.com/pulkit777exe/dots.git ~/dots
~/dots/install.sh
```

Then log out, pick the Hyprland session, and log back in.

### Useful flags

| Command | What it does |
| --- | --- |
| `./dots packages` | Install system packages (no linking) |
| `./dots link` | Symlink configs (dry-run with `--dry-run`) |
| `./dots check` | Verify the live session; make no changes |
| `./dots update` | Re-run clone/update + install (this is the update flow) |
| `./dots --help` | All subcommands |

The per-task scripts behind them (`scripts/setup.sh`, `install.sh`,
`bootstrap.sh`, …) still work directly. `install.sh` is idempotent — run it whenever you pull. It never uses `sudo`
and never deletes: an existing `~/.config/<unit>` is renamed to
`<unit>.pre-install.<timestamp>`, and it asks before doing that unless you
pass `--yes`.

> **Do not run it with `sudo`.** Both scripts refuse to run as root, and they
> mean it. `CONFIG_DIR` comes from `$HOME`, so under sudo the installer would
> link `/root/.config` instead of yours, report success while achieving
> nothing, and leave stray symlinks in root's home pointing into your dotfiles.
> Nothing here needs root — it only writes inside `$HOME`.

### Before you run the one-liner

The one-command install fetches and runs code from a remote, so whoever
controls this repository can run code as you. That is the standard dotfiles
trade-off, but it is a real one. If you'd rather not take it, clone once,
pin a commit, and read what you run — there is no build step and nothing here
fetches anything at runtime, so reading it is a complete audit.

See **[SECURITY.md](SECURITY.md)** for the trust model, what the installer
will and won't touch, and the audit summary.

## Layout

Each top-level directory is one unit that is symlinked into `~/.config/<name>`,
except `zsh/`, whose `.zshrc` is symlinked directly to `~/.zshrc`.

| Unit | What it is |
| --- | --- |
| `hypr/` | Hyprland config in Lua. `hyprland.lua` requires `modules/*` in order; `hypridle.conf` is rendered from the settings store (see the `.example` template) and the idle/wallpaper/night-light daemons start via systemd user units from `modules/startup.lua`. |
| `quickshell/` | The shell. `shell.qml` is the entrypoint; `services/` are singletons, `surfaces/` are windows, `modules/Keybinds.qml` is the shortcut hub. |
| `colors/` | Palettes and the *generated* per-app colour files (`current.json`, `hyprland.conf`, `kitty.conf`, `gtk.css`, `colors.css`, `colors.sh`). |
| `kitty/` | Terminal config. `kitty.conf` includes the generated `../colors/kitty.conf`, so the terminal follows the palette; open instances are repainted live over the remote-control socket. |
| `vlc/`, `Thunar/` | App config. |
| `zsh/` | Shell config. `.zshrc` links to `~/.zshrc`; secrets live in untracked `~/.zshrc.local` (see `zsh/.zshrc.local.example`). |

`hypr/modules/` is the shape to follow when adding config: one file per concern,
`require`d explicitly from `hyprland.lua`, with a header comment explaining
*why* it exists and what it depends on.

## Requirements

Fedora-first. `install.sh --check` reports what's missing.

**Required**

- `hyprland` + `quickshell` — neither is in Fedora's official repos.
  Both come from one COPR: `sudo dnf copr enable nett00n/hyprland &&
  sudo dnf install hyprland quickshell` (`scripts/setup.sh` does this).
  quickshell **must match your Qt6 minor version**.
- `kitty`, `python3`, `cliphist`, `wl-clipboard`
- `zsh` — `sudo dnf install zsh`. The repo manages `~/.zshrc` (see `zsh/`); API
  keys and other secrets stay in untracked `~/.zshrc.local`, never in the repo.
- `hyprpaper` — `modules/startup.lua` starts it and `Theme.qml` drives it. No
  wallpaper without it.
- `hyprlock` — `hypr/hyprlock.lua` is the lock screen; `SUPER + L` calls it.
- `hypridle` — `hypr/hypridle.conf` drives display sleep and idle actions.
- `grim`, `slurp` — screenshot pipeline (`grimblast` is fetched from upstream
  by `scripts/setup.sh` when no enabled repo carries it).
- `Thunar`, `gvfs` — file manager and its volume handling.
- `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk` — screen-share and
  file-chooser portals.
- `polkitd` — the auth daemon. Note it is **not on `PATH`**; it lives at
  `/usr/lib/polkit-1/polkitd`. `install.sh` looks there explicitly, because a
  plain `command -v polkit` check reports a working system as broken.
- `hyprpolkitagent` — the authentication **agent** (from the hyprland COPR).
  polkitd is the authority and is started by systemd; the agent runs in the
  user session (`modules/startup.lua`) and is what actually prompts for a
  password.

**Optional** — the desktop runs without these, but the matching feature is degraded

- `brightnessctl` — `XF86MonBrightness*`
- `playerctl` — `XF86Audio*` media keys
- `openwhispr` — only if you use `hypr/openwhispr-binds.lua`
- `starship`, `zoxide` — prompt and directory jumper in `zsh/.zshrc`; the config guards their absence

**Fonts** — the desktop names three families, two vendored in `fonts/` so a fresh
clone needs no network. `install.sh` installs them automatically.

- `SF Pro Display` — all UI text: shell, settings, lock screen. The one manual
  step: Apple's license forbids vendoring it in a public repo, so copy
  `SF Pro Display Regular.otf` and `SF Pro Display Bold.otf` into
  `~/.local/share/fonts` once (or pass them to the installer:
  `scripts/install-fonts.sh ~/Downloads/*.otf`). Until then Qt substitutes
  automatically, so `--check` treats it as optional, not red.
- `JetBrainsMonoNL Nerd Font Mono` — kitty's terminal font and the lock screen's
  wifi glyph. Vendored: Regular/Bold/Italic/BoldItalic, nerd-fonts v3.5.1 (OFL).
- `Material Symbols Rounded` — every icon glyph in the shell. Vendored: Google's
  variable font (Apache-2.0).

## Keybinds

`SUPER` is the Windows key.

### Shell

| Key | Action |
| --- | --- |
| `SUPER` alone (tap L or R) | Toggle launcher |
| `SUPER + D` | Toggle launcher |
| `SUPER + /` | Toggle launcher (direct exec bind, see below) |
| `SUPER + N` | Control centre |
| `SUPER + S` | Settings |
| `SUPER + T` | Theme picker |
| `SUPER + W` | Wallpaper picker |
| `SUPER + C` | Clipboard manager |
| `SUPER + SHIFT + L` | Power menu |
| `SUPER + ESCAPE` | Close all overlays |
| `SUPER + R` | Reload desktop (Hyprland config + shell restart) |

These go through Hyprland's `global` dispatcher, so they cost no process
spawn and show up in `hyprctl globalshortcuts`. The source of truth for the
names is `quickshell/modules/Keybinds.qml`; `hypr/modules/keybinds/quickshell.lua`
must match it 1:1. If you add one, add it to both.

`SUPER + R` is the exception: it is a direct exec bind with no `Keybinds.qml`
twin, because it restarts the shell and must fire even when the shell is
wedged or mid-restart. `SUPER + /` (launcher) and `SUPER + Q` (close window,
in `hypr/modules/keybinds/applications.lua`) are likewise direct binds, not
global shortcuts — they predate the shortcut hub and still fire without a
round-trip through it.

### Windows and workspaces

| Key | Action |
| --- | --- |
| `SUPER + V` | Toggle floating |
| `SUPER + F` | Toggle fullscreen |
| `SUPER + SHIFT + V` | Toggle pseudo-tiling |
| `SUPER + arrows` | Focus direction |
| `SUPER + SHIFT + arrows` | Move window |
| `SUPER + ALT + arrows` | Swap window with neighbour |
| `ALT + TAB` / `ALT + SHIFT + TAB` | Cycle windows |
| `SUPER + 1..9`, `SUPER + 0` | Focus workspace (0 = 10) |
| `SUPER + SHIFT + 1..9`, `+ 0` | Move window to workspace |
| `SUPER + CTRL + arrows` | Resize |
| `SUPER + Return` | Open kitty |
| `SUPER + L` | Lock screen |
| `SUPER + Q` | Close window |

### Media and screen

| Key | Action |
| --- | --- |
| `XF86Audio{Raise,Lower}Volume` | Volume ±5% |
| `XF86AudioMute` / `XF86AudioMicMute` | Mute output / input |
| `XF86Audio{Next,Prev,Play,Pause}` | Media keys via `playerctl` |
| `XF86MonBrightness{Up,Down}` | Brightness via `brightnessctl` |
| `Print` / `SHIFT + Print` / `CTRL + Print` | Screenshot variants |

The media and brightness keys deliberately use the raw `wpctl` / `playerctl` /
`brightnessctl` commands rather than the shell, so they keep working when
Quickshell is restarting or has failed. Equivalent shell-backed handlers exist
in `Keybinds.qml` and can be enabled by uncommenting the block at the bottom of
`hypr/modules/keybinds/quickshell.lua` — don't enable them without also removing
the raw binds in `hypr/modules/keybinds/media.lua`, or the keys will fire twice.

## Theming

Colours flow one direction:

Palettes are static and picked by name — there is no wallpaper sampling. Colours
flow one direction:

```
you pick a palette  (CLI arg -> $QUICKSHELL_THEME -> colors/index.json `current`)
  -> quickshell/scripts/publish-colors.py
  -> ~/.config/colors/current.json + hyprland.conf, colors.css, colors.sh, gtk.css, kitty.conf
  -> every app
```

GTK note: a user-stylesheet `@define-color` does **not** override Adwaita's
own definitions on this stack (verified — redefined `theme_selected_bg_color`
still rendered blue while a direct rule in the same file applied, and accent
widgets paint via `background-image`, which sits over `background-color`).
So `publish-colors.py` writes **explicit widget rules with literal colors**
into `~/.config/gtk-3.0/gtk.css` (window, views, selection, headerbar,
sidebar, popovers, switches) and `~/.config/gtk-4.0/gtk.css` (selection,
accent button, checks, switches), using the `background:` shorthand so the
theme's background images don't survive underneath. Icon glyphs (e.g.
folder icons) come from the icon theme, not CSS — `publish-colors.py`
generates a minimal `dots` theme (Adwaita underneath, palette-tinted
`folder`/`folder-open` only) into `~/.local/share/icons/dots` and selects
it, so folders re-tint with every palette.

- **Palettes** live in `colors/themes/<name>/colors.json`, one flat object of
  18 colour keys. Add a palette by dropping a new directory in there and running
  `quickshell/scripts/list-themes.py`; nothing else needs to change.
- **`kitty.conf` is applied.** `kitty.conf` includes the generated palette for
  future launches, and every palette push repaints open terminals live over
  their remote-control sockets.
- **The active palette** is `colors/index.json`'s `current`. Its `themes` key is
  an *object* mapping palette key → metadata, **not** a list.
  `quickshell/scripts/list-themes.py`
  reads it, fills in each palette's `wallpaperDir` by probing the usual locations,
  and writes the result back. If you hand-edit it, keep it an object.
- **Wallpapers** live in `~/Pictures/Themes/<theme>/`, one directory per
  palette. Older spots (`~/Downloads/<palette>`, `~/Pictures/Wallpapers/<palette>`,
  `~/wallpapers/<theme>`, `colors/themes/<theme>/`) still work as fallbacks.
  They are *not* committed (they are large binaries) — point `wallpaperDir`
  at your own copy.
  `quickshell/scripts/generate-theme-wallpapers.py` will synthesise
  palette-matched placeholders if you just want something coherent.
- `hypr/modules/colours.lua` reads `colors/hyprland.conf` once per startup;
  `general.lua` derives the border colours from it and `decoration.lua` the
  window shadow and the accent glow, so a fresh login matches your last palette.

## Updating

```bash
~/dots/bootstrap.sh          # pull --ff-only, then reinstall
~/dots/install.sh --check    # confirm the result
```

`install.sh` moves any conflicting directory to `<name>.pre-install.<timestamp>`
rather than overwriting it, so your previous config is always recoverable.

## Troubleshooting

Start with the checker — it verifies the symlinks, the files Hyprland and the
global shortcuts depend on, the fonts, and the shape of the theme catalog:

```bash
./install.sh --check
```

**Nothing happens when I press `SUPER + N`.** The global shortcuts need the
`Keybinds` singleton to be alive. Confirm `quickshell/modules/qmldir` still says
`singleton Keybinds 1.0 Keybinds.qml` and that `shell.qml` imports `qs.modules`,
then check `quickshell ipc show` lists the `shell` and `uis` targets and
`hyprctl globalshortcuts` lists `quickshell:*`.

**Theme picker is empty / theme switching does nothing.** Theme discovery runs
`quickshell/scripts/list-themes.py`. Run it by hand to see the error:

```bash
python3 quickshell/scripts/list-themes.py | head
```

**Colours didn't update.** `publish-colors.py` drives kitty over its remote
control socket, so `allow_remote_control yes` in `kitty/kitty.conf` must survive
— it is required for the live path to reach already-open windows.

**A config change had no effect.** Some of these files are only read at session
start. `hyprctl reload` re-reads the Hyprland config; Quickshell changes need
the shell restarted (log out/in, or restart the `quickshell -p` process). To
confirm a reload actually loaded, look for the `Reloading configuration...` /
`Configuration Loaded` pair in `quickshell/scripts/shell-log.sh tail` — not in
the journal, which never sees this shell at all (see **The shell's log is not
in the journal** below).

## Layout of the shell

| Path | Role |
| --- | --- |
| `shell.qml` | Entrypoint. Loads surfaces, imports `qs.modules` for the keybind hub. |
| `services/` | QML singletons, one per concern, declared in `services/qmldir`. `Theme` holds the palette. |
| `surfaces/` | Windows: launcher, control centre, settings, theme and wallpaper pickers, power menu, notification toasts. |
| `components/` | Reusable UI primitives. Nothing else lives here. |
| `modules/Keybinds.qml` | Single place mapping shortcut names → actions. |
| `scripts/` | Python helpers: palette discovery, publishing, wallpaper generation. |
| `themes/` | Shell-side theme definitions. |

### Adding a surface

Chrome comes from `components/Surface.qml` — shadow, border and radius are
its defaults — and colours come from `Theme.cc.*` / `Theme.colors` only, so
every surface re-tints with the theme and no hex literal lives outside the
palette. Copy the shape of an existing surface (`PowerMenu.qml` is the
smallest) rather than inventing a new one; popups are `PopupPanel` roots and
`shell.qml` owns their position.

Use `Theme.colors` only for things that should recolour with the theme: accent
fills, selected states, and semantic colours.

Check the result with:

```bash
qmllint-qt6 -I . -I services -I components -I surfaces $(find . -name '*.qml')
```

Use `qmllint-qt6`, not `qmllint`. On a machine with both the Qt5 and Qt6
devel packages installed, `/usr/bin/qmllint` is the **Qt5** binary: it
reports `qmllint 1.0`, analyses nothing, and exits 0 with an empty log on
this whole tree. `scripts/lint.sh` resolves a Qt6 linter explicitly and
fails on an empty log for exactly that reason.

Note that `qmllint` passing does not mean the config loads. It does not
resolve Quickshell's `Singleton` base type, so a service can lint clean and
still fail at runtime with "Type X unavailable". It also cannot be trusted
with an import it cannot resolve — that case exits 0 silently, which is why
`lint.sh` separately asserts every `Quickshell.*` module this tree imports
is present in the installed `quickshell` binary. When you add a service,
actually start the shell and read the log:

```bash
quickshell -c ~/.config/quickshell
```

## Documentation

| | |
|---|---|
| `README.md` | this file -- installing, verifying, and the traps worth knowing before you change something |
| `quickshell/ARCHITECTURE.md` | how the shell is put together, plus the complete IPC reference (checked against the running shell by `tests/run.sh`, so it cannot drift) |
| `SECURITY.md` | what is and is not sandboxed |

Three checks worth running after any change:

```bash
./scripts/lint.sh                    # grep rules, the IpcHandler scope audit,
                                     # the Quickshell module-presence check,
                                     # and qmllint (Qt6)
./tests/run.sh                       # contract tests: theme round trip, IPC,
                                     # surfaces
quickshell/scripts/shell-log.sh tail # what the *running* shell actually logged
```

`tests/run.sh` skips the checks that need a running shell when there isn't
one, so it is safe to run on a fresh clone.

### The shell's log is not in the journal

The third command is not redundant with the other two — it is the only way to
see what the running shell did. Hyprland starts Quickshell with stdout and
stderr on `/dev/null`, so:

```bash
journalctl --user -b _PID=$(pgrep -x quickshell)   # No entries
journalctl --user -b | grep -i quickshell         # only systemd's own
                                                  # start/stop lines, and
                                                  # coredump records
```

Both are satisfied by a shell that is failing. Don't treat either as a check.
The shell writes its own log at
`/run/user/$UID/quickshell/by-pid/<pid>/log.log` — a symlink into
`by-id/<instance>/` — and announces that directory as its third log line
(`Saving logs to ".../by-id/<instance>/log.qslog"`), so the directory is not a
guess. `log.qslog` is Quickshell's structured log; `log.log` next to it is the
same content as plain text. `shell-log.sh` reads the text one:

```bash
quickshell/scripts/shell-log.sh path                     # the resolved path
quickshell/scripts/shell-log.sh tail 40                  # last 40 lines
quickshell/scripts/shell-log.sh errors                   # ERROR lines only
quickshell/scripts/shell-log.sh errors "2026-10-02 17:11:44"
```

`errors` takes an optional `YYYY-MM-DD HH:MM:SS` and exits **3** when it
matched nothing, so the last one is a check that can actually fail. Every mode
exits 1 with a single line on stderr when no shell is running. If a scratch
`quickshell -c /tmp/...` is up alongside the session shell, it reads the
**oldest** instance (lowest PID, i.e. the one Hyprland started); `--pid <pid>`
overrides that.
