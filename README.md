# dots

Fedora Hyprland + Quickshell desktop config.

## Install

On a fresh Fedora install, run one command:

```bash
git clone https://github.com/pulkit777exe/dots.git ~/dots
~/dots/install
```

Or as a single bootstrap command:

```bash
curl -fsSL https://raw.githubusercontent.com/pulkit777exe/dots/main/bootstrap.sh | bash
```

`./install` is idempotent. It installs required packages and session components, links configs into `~/.config` and `~/.zshrc`, generates runtime state (colors, lock/idle config, Hyprland overrides), and verifies the result. Existing files are moved aside with a `.pre-install.<timestamp>` suffix, never deleted.

After install, log out and choose the Hyprland session.

## Commands

- `./install` — one-shot install/provision on Fedora
- `./install.sh --check` or `./dots check` — verify install
- `./dots link` — symlink configs only
- `./dots packages [--all|--desktop|--shell|--session|--nvidia|--dev]` — package groups
- `./dots update` — update clone and re-link

## Notes

- SF Pro Display cannot be redistributed. If missing, place the font files in `~/.local/share/fonts` or run `./dots fonts /path/to/*.otf`; the desktop falls back until then.
- Generated files live in `~/.config/colors/`, `~/.config/hypr/hyprlock.conf`, `~/.config/hypr/hypridle.conf`, and `~/.local/state/quickshell/`.
- Desktop settings are stored in Quickshell state and applied to Hyprland through a generated override file.
