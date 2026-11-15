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

- `./install [--dry-run|--check]` — one-shot install/verify
- `./dots check` — verify install
- `./dots link` — link configs only
- `./dots packages [--all|--desktop|--shell|--session|--nvidia|--dev]` — package groups only
- `./dots update` — update and re-run bootstrap

## Notes

- Designed for Fedora with actively maintained components (Hyprland, Quickshell, PipeWire, SDDM, etc.).
- SF Pro Display cannot be redistributed; if missing, place fonts in `~/.local/share/fonts` or run `./dots fonts /path/to/*.otf`.
- Generated state lives in `~/.config/colors/`, `~/.config/hypr/`, and `~/.local/state/quickshell/`. Desktop settings apply through generated Hyprland overrides.
