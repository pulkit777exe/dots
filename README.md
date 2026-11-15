# dots

Fedora Hyprland + Quickshell desktop config.

## Install

On a fresh Fedora system:

```bash
git clone https://github.com/pulkit777exe/dots.git ~/dots
~/dots/install
```

Preview without changing anything:

```bash
~/dots/install --dry-run
```

Bootstrap (clone/update + install):

```bash
curl -fsSL https://raw.githubusercontent.com/pulkit777exe/dots/main/bootstrap.sh | bash
```

`install` is idempotent. It provisions packages/session components, links configs into `~/.config` and `~/.zshrc`, generates runtime state, and verifies the result. Existing files are moved aside with a `.pre-install.<timestamp>` suffix.

After install, log out and choose the Hyprland session.

## Commands

- `./install [--dry-run|--check]` — one-shot install/verify (phased apply + critical runtime checks)
- `./dots check` / `./dots doctor` — verify install, generated state, services, and session readiness
- `./dots link [--dry-run|--yes]` — link configs and regenerate/verify runtime state
- `./dots migrate [--dry-run|--pending]` — apply/list marker-based repo migrations (`migrations/*.sh`)
- `./dots packages [--all|--desktop|--shell|--session|--nvidia|--dev]` — package groups only
- `./dots update` — update and re-run bootstrap

## Notes

- Designed for Fedora with actively maintained components (Hyprland, Quickshell, PipeWire, SDDM, etc.).
- Idempotent by design: existing files are backed up as `*.pre-install.<timestamp>` (never deleted), services/config are applied with presence checks where possible, and repo migrations run once per user via markers in `$XDG_STATE_HOME/dots/migrations/`.
- Managed/generated state lives in `~/.config/colors/`, `~/.config/hypr/` (including generated `hypridle.conf`/`hyprlock.conf`), and `~/.local/state/quickshell/` (including generated `hypr.lua`). User-specific/local secrets should stay out of managed repo files.
- SF Pro Display cannot be redistributed; if missing, place fonts in `~/.local/share/fonts` or run `./dots fonts /path/to/*.otf`.
