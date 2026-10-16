# dots

hyprland (lua) + quickshell (qml) desktop for fedora. one repo, reproducible, no cap.
everything color-related is generated from one palette per theme. no wallpaper sampling fr.

## install

fresh fedora machine? three steps, then reboot:

```bash
git clone https://github.com/pulkit777exe/dots.git ~/dots
~/dots/dots packages --all    # dnf stuff, drivers, shell tooling, login theme
~/dots/dots link              # symlink configs into ~/.config + ~/.zshrc
~/dots/dots apps              # brave + flatpaks (needs a terminal for sudo)
```

- everything is idempotent. pull, re-run, done.
- never runs as root. sudo is per-dnf-command only. **do not sudo it** — under sudo `$HOME` is `/root` and you'd link root's config. it refuses root anyway.
- existing configs get moved aside (`<unit>.pre-install.<timestamp>`), never deleted. `--yes` skips the prompt.
- `--nvidia` needs a reboot after. secure boot needs the akmods key enrolled once (script prints the cmd).
- fedora server boots to tty btw. `--session` (on by default) installs sddm + uwsm, sets graphical target, enables sddm. reboot = login screen.
- brave asking for keyring pw every boot? your login keyring pw doesn't match your login pw. seahorse → make a `Login` keyring with your login pw, set as default, move items over, relog.

configs only, packages already handled:

```bash
curl -fsSL https://raw.githubusercontent.com/pulkit777exe/dots/main/bootstrap.sh | bash
# or: git clone ... ~/dots && ~/dots/install.sh  → log out → pick hyprland → log in
```

curl-pipebash = whoever owns this repo runs code as you. standard dotfiles tradeoff but be aware. want out? clone, pin a commit, read it (no build step, zero runtime fetching, fully auditable). details → [SECURITY.md](SECURITY.md).

## commands

| cmd | does what |
| --- | --- |
| `./dots packages [--all\|--desktop\|--shell\|--session\|--nvidia\|--dev]` | dnf groups. default = desktop + shell + session |
| `./dots link [--dry-run] [--yes]` | symlink units |
| `./dots check` | verify everything, change nothing |
| `./dots lint` | static checks (qml rules, ipc scope, imports, qmllint) |
| `./dots test` | contract tests (some need a live shell, rest skip) |
| `./dots fonts [files...]` | vendored fonts (+ optional sf pro .otf paths) |
| `./dots session` | login session bits only |
| `./dots apps` | brave + flatpaks |
| `./dots update` | pull + reinstall |

old scripts still work directly (`scripts/setup.sh`, `install.sh`, `install-software`, `scripts/install-sddm.sh`).

## layout

each dir = one unit symlinked to `~/.config/<name>`, except `zsh/.zshrc` → `~/.zshrc`.

| unit | what |
| --- | --- |
| `hypr/` | hyprland in lua. `hyprland.lua` requires `modules/*` in order. `hypridle.conf` renders from settings (see `.example`). daemons start via user units in `modules/startup.lua` |
| `quickshell/` | the shell. `shell.qml` entrypoint, `services/` singletons, `surfaces/` windows, `modules/Keybinds.qml` shortcut hub |
| `colors/` | palettes + generated files (`current.json`, `hyprland.conf`, `kitty.conf`, `gtk.css`, `colors.css`, `colors.sh`) |
| `kitty/` | terminal. includes generated `../colors/kitty.conf`, follows palette, live-repaints open terms |
| `vlc/`, `Thunar/` | app config |
| `zsh/` | shell. secrets go in untracked `~/.zshrc.local`, never the repo |

adding hypr config? one file per concern in `hypr/modules/`, required from `hyprland.lua`, header comment says why + deps. that's the pattern, stick to it.

## needs

fedora-first. `./dots check` snitches what's missing.

**required:** `hyprland` + `quickshell` (copr `nett00n/hyprland` — `setup.sh` does it; quickshell must match your qt6 minor), `kitty python3 cliphist wl-clipboard zsh`, `hyprpaper` (no wallpaper without it), `hyprlock` (`super+l`), `hypridle`, `grim slurp` (grimblast fetched by setup if no repo has it), `Thunar gvfs`, both xdg portals (hyprland + gtk), `polkitd` (lives at `/usr/lib/polkit-1/polkitd`, not on path — check looks there), `hyprpolkitagent` (manual fallback; session ships its own agent, currently dormant cuz no logind session — see SECURITY.md).

**optional (feature degrades without):** `brightnessctl` (brightness keys), `playerctl` (media keys), `hyprsunset` (night light), `openwhispr` (only for its binds file), `starship zoxide` (prompt/jumper, guarded).

**fonts** (two vendored, auto-installed; one manual): `sf pro display` = all ui text — apple won't let us vendor it, so drop `SF Pro Display Regular/Bold.otf` in `~/.local/share/fonts` once (or `dots fonts ~/Downloads/*.otf`). till then qt substitutes, check stays green. `JetBrainsMonoNL Nerd Font Mono` (kitty + lock wifi glyph, vendored) + `Material Symbols Rounded` (shell icons, vendored).

## keybinds

`super` = windows key. these ride hyprland's `global` dispatcher (no spawn cost, visible in `hyprctl globalshortcuts`). truth = `quickshell/modules/Keybinds.qml`, must match `hypr/modules/keybinds/quickshell.lua` 1:1. add one? add it in both.

| key | does what |
| --- | --- |
| `super` tap (l/r), `super+d`, `super+/` | launcher |
| `super+n` / `s` / `t` / `w` / `c` | control centre / settings / themes / wallpapers / clipboard |
| `super+shift+l` | power menu |
| `super+esc` | close all overlays |
| `super+r` | reload desktop (hyprland + shell restart) — direct exec, no Keybinds twin, works even when shell is wedged |
| `super+v` / `f` / `shift+v` | float / fullscreen / pseudo-tile toggle |
| `super+arrows` / `+shift` / `+alt` | focus / move / swap |
| `alt+tab` / `+shift` | cycle windows |
| `super+1..0` / `+shift` | workspace focus (0 = 10) / move window there |
| `super+ctrl+arrows` | resize |
| `super+return` / `l` / `q` | kitty / lock / close window |
| `XF86Audio*` | volume ±5%, mute in/out, next/prev/play/pause via playerctl |
| `XF86MonBrightness*` | brightness |
| `print` / `shift+print` / `ctrl+print` | screenshot area / window / output |

media/brightness keys use raw `wpctl`/`playerctl`/`brightnessctl` on purpose — they work while quickshell is restarting. shell-backed versions exist in Keybinds.qml; enabling those without removing `media.lua` = double-fire. don't.

## theming

one direction, no magic:

```
pick palette (cli arg → $QUICKSHELL_THEME → index.json `current`)
  → publish-colors.py
  → current.json + hyprland.conf, colors.css, colors.sh, gtk.css, kitty.conf
  → every app
```

- palettes = `colors/themes/<name>/colors.json`, flat 18-key object. new palette = new dir + run `list-themes.py`. that's it.
- `index.json`'s `themes` is an **object** (key → metadata), not a list. keep it that way or discovery breaks.
- wallpapers = `~/Pictures/Themes/<theme>/` (+ fallbacks: `~/Downloads`, `~/Pictures/Wallpapers`, `~/wallpapers`, theme dir). not committed (binaries, duh).
- hypr reads `colors/hyprland.conf` at startup for borders/shadow/glow. gtk gets explicit literal rules (define-color restyle doesn't stick on this stack) + a generated `dots` icon theme for folders.
- kitty follows palette live over remote-control sockets. keep `allow_remote_control yes` or open terms won't repaint.

## update

```bash
~/dots/bootstrap.sh          # pull --ff-only, then reinstall
~/dots/install.sh --check   # confirm
```

## troubleshooting

start here: `./dots check` (symlinks, hypr/globalshortcut deps, fonts, catalog shape).

- **`super+n` does nothing** → Keybinds singleton dead. `qmldir` still say `singleton Keybinds 1.0 Keybinds.qml`? `shell.qml` import `qs.modules`? `quickshell ipc show` list `shell` + `uis`? `hyprctl globalshortcuts` list `quickshell:*`?
- **theme picker empty** → run `python3 quickshell/scripts/list-themes.py | head`, read the error.
- **colors didn't update** → `allow_remote_control yes` must be in kitty.conf (live repaint needs it).
- **change had no effect** → some files are session-start-only. `hyprctl reload` for hypr; shell changes need a shell restart. confirm via `shell-log.sh tail` (`Reloading configuration...` / `Configuration Loaded`) — NOT the journal (see below).

## shell dev

| path | role |
| --- | --- |
| `shell.qml` | entrypoint. surfaces + `qs.modules` keybind hub |
| `services/` | singletons, one per concern (`services/qmldir`). `Theme` holds palette |
| `surfaces/` | windows: launcher, cc, settings, pickers, power menu, toasts |
| `components/` | shared ui primitives only |
| `modules/Keybinds.qml` | shortcut names → actions, single place |
| `scripts/` | python: discovery, publishing, idle-conf, monitors |

new surface? chrome = `components/Surface.qml`, colors only from `Theme.cc.*`/`Theme.colors` (no hex literals outside palette), copy `PowerMenu.qml` (smallest), root = `PopupPanel`, position lives in `shell.qml`. theme-only things use `Theme.colors`.

checks after any change: `./dots lint` (rules + ipc scope + module presence + qmllint-qt6) and `./dots test` (round trip + ipc + surfaces). heads up: use `qmllint-qt6`, not `qmllint` — `/usr/bin/qmllint` is qt5, analyzes nothing, exits 0. lint.sh knows. also qmllint passing ≠ loads (can't resolve quickshell `Singleton`) — actually boot the shell and read the log:

```bash
quickshell -c ~/.config/quickshell
```

### logs aren't in the journal fr

hyprland starts quickshell with stdout/stderr on `/dev/null`, so `journalctl --user -b _PID=$(pgrep -x quickshell)` = empty, and grepping the journal only finds systemd start/stop + coredumps. both pass on a broken shell. useless as checks, ngl.

real log: `/run/user/$UID/quickshell/by-pid/<pid>/log.log` (symlink into `by-id/<instance>/`). helper:

```bash
quickshell/scripts/shell-log.sh path                     # resolved path only
quickshell/scripts/shell-log.sh tail 40                  # last 40 lines
quickshell/scripts/shell-log.sh errors                   # ERROR lines only
quickshell/scripts/shell-log.sh errors "2026-10-02 17:11:44"  # since timestamp
```

`errors` exits 3 on no match (so it's a real check) and 1 when no shell runs. scratch instance alongside session shell? reads oldest pid (the session one); `--pid` overrides.

## docs

| file | what |
| --- | --- |
| `README.md` | this. install, verify, traps |
| `quickshell/ARCHITECTURE.md` | shell internals + full ipc ref (test-checked, can't drift) |
| `SECURITY.md` | trust model, sandbox notes |
| `sddm/README.md` | login theme |
| `fonts/README.md` | vendored fonts |
