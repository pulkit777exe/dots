# dots

A Hyprland + Quickshell desktop environment for Fedora, kept as one
reproducible repo. The compositor config is Lua; the shell (bar, launcher,
control centre, clipboard, theme and wallpaper pickers) is Quickshell/QML;
everything colour-related is generated from a single palette per theme.

## Install

One command on a fresh machine:

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
| `./install.sh --dry-run` | Print the plan, change nothing |
| `./install.sh --check` | Verify the live session; make no changes |
| `./install.sh --yes` | Relocate existing configs without prompting |
| `./bootstrap.sh` | Re-run clone/update + install (this is the update flow) |

`install.sh` is idempotent — run it whenever you pull. It never uses `sudo`
and never deletes: an existing `~/.config/<unit>` is renamed to
`<unit>.pre-install.<timestamp>`, and it asks before doing that unless you
pass `--yes`.

### Before you run the one-liner

The one-command install fetches and runs code from a remote, so whoever
controls this repository can run code as you. That is the standard dotfiles
trade-off, but it is a real one. If you'd rather not take it, clone once,
pin a commit, and read what you run — there is no build step and nothing here
fetches anything at runtime, so reading it is a complete audit.

See **[SECURITY.md](SECURITY.md)** for the trust model, what the installer
will and won't touch, and the audit summary.

## Layout

Each top-level directory is one unit that is symlinked into `~/.config/<name>`.

| Unit | What it is |
| --- | --- |
| `hypr/` | Hyprland config in Lua. `hyprland.lua` requires `modules/*` in order. |
| `quickshell/` | The shell. `shell.qml` is the entrypoint; `services/` are singletons, `surfaces/` are windows, `modules/Keybinds.qml` is the shortcut hub. |
| `colors/` | Theme palettes and the *generated* per-app colour files (`current.json`, `hyprland.conf`, `kitty.conf`, `gtk.css`, `colors.css`, `colors.sh`). |
| `kitty/` | Terminal config. `current-theme.conf` is generated; `kitty.conf` includes it. |
| `vlc/`, `Thunar/` | App config. |

`hypr/modules/` is the shape to follow when adding config: one file per concern,
`require`d explicitly from `hyprland.lua`, with a header comment explaining
*why* it exists and what it depends on.

## Requirements

Fedora-first. `install.sh --check` reports what's missing.

**Required**

- `hyprland` — `sudo dnf copr enable solopasha/hyprland && sudo dnf install hyprland hyprlock hypridle hyprpaper`
- `quickshell` — not in Fedora's official repos. Needs a COPR build (availability
  moves fast) or a source build, and **must match your Qt6 minor version**.
- `kitty`, `python3`, `cliphist`, `wl-clipboard`, `polkit`, `hyprpaper`

**Optional** — the desktop runs without these, but the matching feature is degraded

- `brightnessctl` — `XF86MonBrightness*`
- `playerctl` — `XF86Audio*` media keys
- `iris` — dynamic per-wallpaper colours (see Theming)
- `openwhispr` — only if you use `hypr/openwhispr-binds.lua`

## Keybinds

`SUPER` is the Windows key.

### Shell

| Key | Action |
| --- | --- |
| `SUPER` alone (tap L or R) | Toggle launcher |
| `SUPER + D` or `SUPER + /` | Toggle launcher |
| `SUPER + N` | Control centre |
| `SUPER + S` | Settings |
| `SUPER + C` | Clipboard history |
| `SUPER + T` | Theme picker |
| `SUPER + W` | Wallpaper picker |
| `SUPER + SHIFT + C` | Calendar |
| `SUPER + SHIFT + L` | Power menu |
| `SUPER + ESCAPE` | Close all overlays |

These go through Hyprland's `global` dispatcher, so they cost no process
spawn and show up in `hyprctl globalshortcuts`. The source of truth for the
names is `quickshell/modules/Keybinds.qml`; `hypr/modules/keybinds/quickshell.lua`
must match it 1:1. If you add one, add it to both.

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

```
iris (samples the wallpaper)
  -> ~/.cache/iris/colors.json
  -> quickshell/services/Iris.qml
  -> quickshell/scripts/publish-colors.py
  -> ~/.config/colors/current.json + hyprland.conf, kitty.conf, gtk.css, colors.css, colors.sh
  -> every app
```

- **Static palettes** live in `colors/themes/<name>/colors.json`. These are
  fallbacks used when `iris` is unavailable.
- **The active theme** is `colors/index.json`. Its `themes` key is an *object*
  mapping theme key → metadata, **not** a list. `quickshell/scripts/list-themes.py`
  reads it, fills in each theme's `wallpaperDir` by probing the usual locations,
  and writes the result back. If you hand-edit it, keep it an object.
- **Wallpapers** are looked for in `~/Downloads/<theme>`, `~/Pictures/Wallpapers/<theme>`,
  `~/wallpapers/<theme>`, then `colors/themes/<theme>/`. They are *not* committed
  (they are large binaries) — point `wallpaperDir` at your own copy.
  `quickshell/scripts/generate-theme-wallpapers.py` will synthesise
  palette-matched placeholders if you just want something coherent.
- `hypr/modules/general.lua` seeds Hyprland's border colours from
  `colors/hyprland.conf` at startup; `publish-colors.py` then updates them live
  on every theme switch, so a fresh login matches your last theme.

## Updating

```bash
~/dots/bootstrap.sh          # pull --ff-only, then reinstall
~/dots/install.sh --check    # confirm the result
```

`install.sh` moves any conflicting directory to `<name>.pre-install.<timestamp>`
rather than overwriting it, so your previous config is always recoverable.

## Troubleshooting

Start with the checker — it verifies the symlinks, the files Hyprland and the
global shortcuts depend on, and the shape of the theme catalog:

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
the shell restarted (log out/in, or restart the `quickshell -p` process).

## Layout of the shell

| Path | Role |
| --- | --- |
| `shell.qml` | Entrypoint. Loads surfaces, imports `qs.modules` for the keybind hub. |
| `services/` | QML singletons, one per concern, declared in `services/qmldir`. `Theme` is the palette, `Solid` is the shared surface chrome. |
| `surfaces/` | Windows: launcher, control centre, OSD, pickers. |
| `components/` | Reusable UI primitives. Nothing else lives here. |
| `modules/Keybinds.qml` | Single place mapping shortcut names → actions. |
| `scripts/` | Python helpers: palette discovery, publishing, wallpaper generation. |
| `themes/` | Shell-side theme definitions. |

### Adding a surface

Two colour systems, and picking the wrong one is the fastest way to make the
shell look inconsistent:

- **`Theme.colors`** — the palette. Recolours when the theme changes. Use for
  accent fills, selected states, and anything semantic.
- **`Solid`** — the surface chrome: a fixed near-black layering system plus the
  radii. Deliberately *not* themed; switching theme recolours the highlights,
  not the furniture.

Take colours from those, never from hex literals, and use `Solid.fg(a)` /
`Solid.muted(a)` rather than `Qt.rgba(1, 1, 1, a)` for anything sitting on a
theme-coloured fill. Check the result with:

```bash
qmllint -I . -I services -I components -I surfaces $(find . -name '*.qml')
```

See `quickshell/ARCHITECTURE.md` for the longer version.
