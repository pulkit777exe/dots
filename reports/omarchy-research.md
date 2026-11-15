# Omarchy — Deep Research Report (bottom-facts update)

**Repo:** https://github.com/omacom/omarchy  
**Default branch:** `quattro` (per GitHub API)  
**Homepage/manual:** https://omarchy.org / `manual/` in repo  
**License:** MIT  
**Research date:** 2026-11-15 (live GitHub API + raw source inspection)

## 1. Verified project facts

- **Identity/scope:** "Beautiful, Modern & Opinionated Linux" desktop distribution by DHH (Arch-based, Hyprland-centric). Repo includes full OS-facing install/config/update/migration/manual/i18n/assets, not only dotfiles.
- **Activity (GitHub API snapshot):** stars ~47,007; forks ~6,122; open issues ~6,899; watchers ~47,007; created 2025-06-01; pushed 2026-11-14; updated 2026-11-15; default branch `quattro`; discussions enabled.
- **Latest stable release:** `v4.5.0` (2026-11-05) with extensive changelog/breaking changes; RCs present (`v4.5.0-rc3`, `v4.5.0-rc2`).
- **CI/process signals:** workflows `test.yml`, `i18n-check.yml`, `i18n-sync.yml`, `visual-evidence.yml`; `SECURITY.md`, issue/PR templates, `AGENTS.md`, `agents/skills/*`, large `manual/` (50+ sections listed in README).

## 2. Core architecture (source-verified)

### 2.1 Command platform: `bin/omarchy`
`bin/omarchy` is a metadata-aware dispatcher/router, not a thin wrapper:
- Scans executable `bin/omarchy-*` commands and parses header metadata (`omarchy:group/name/summary/args/examples/alias(es)/requires-sudo/hidden`) within a scan window.
- Builds route maps (primary + filename fallback + aliases), detects route collisions, and supports grouped discovery/help.
- Resolves direct binary routes fast (`omarchy-<words>`), falls back to candidate loading by first token, and provides help/JSON output paths.
- Exposes discovery/validation commands: `omarchy commands [--all|--json|--markdown|--check]`, per-command `--help/--json`, group help.
- Includes hardcoded group descriptions for a very large surface (agent, audio, bar, update, channel, migrate, snapshot, hardware, theme, etc.).

**Bottom fact:** command UX and validation are first-class infrastructure; scripts are intended to be self-describing and machine-discoverable.

### 2.2 Install composition (`install/`)
- `install/config/all.sh` runs modular config steps in order via `run_logged`: theme-system, browser-policy, lockout limit, lockscreen PAM, ssh command path/keepalive, docker, locale, language, snapper, enable-services, firewall.
- `install/config/enable-services.sh` **enables (does not start/reload)** services during install because reboot follows: `cups`, `avahi-daemon`, `linux-modules-cleanup`, `docker.socket`, `systemd-resolved`, `NetworkManager`, `power-profiles-daemon`, `sddm`, `systemd-oomd`; masks `NetworkManager-wait-online.service` to avoid blocking graphical target on network-online waits.
- `install/config/firewall.sh` sets UFW defaults (deny incoming/allow outgoing), allows LocalSend ports, allows Docker DNS from common bridge ranges, installs ufw-docker rules via a temporary shim because ISO/finalization must not mutate the live installer's firewall state, writes `ENABLED=yes` in `/etc/ufw/ufw.conf`, and enables `ufw` for post-reboot activation.
- `install/helpers/pacman.sh` defines platform-aware template selection (`x86`, `aarch64`, Apple Silicon, Qualcomm/N1x/GB10 mapping) and default channel behavior (Apple Silicon defaults to edge; others stable) without mutating state at source time.
- `install/omarchy-base.packages` shows a curated, actively maintained desktop stack: Hyprland/quickshell/uwsm/sddm/portals, PipeWire-adjacent media/capture tools, NetworkManager/bluez/cups/avahi, snapper, ufw/ufw-docker, docker/podman, mise, nvim/omarchy packages, fonts/IME (fcitx5), etc.

### 2.3 Migration system (`bin/omarchy-migrate`, `migrations/`)
- Migration source dir: `$OMARCHY_PATH/migrations` (default `/usr/share/omarchy/migrations`); state markers: `$OMARCHY_MIGRATION_STATE` or `~/.local/state/omarchy/migrations`.
- `omarchy-migrate --pending|--check` lists unapplied `*.sh` migrations (exit 0 if any pending, else 1).
- On run: waits for pacman transaction lock (`/var/lib/pacman/db.lck`, up to 900s) and exits cleanly to retry later if still locked.
- Executes each unapplied migration once with `bash -euo pipefail` in filename order scan, then creates a per-migration marker file under state dir (idempotent-by-marker behavior).
- Clears stale "Omarchy Migrations" notifications after completion.
- Migration scripts are timestamp-named shell programs that directly adjust user/system config or package state (example `1780057136.sh` rewrites Waybar configs, appends CSS, installs/restarts components conditionally).

**Bottom fact:** update safety relies heavily on timestamped, one-shot, marker-tracked migrations plus pacman-lock awareness.

### 2.4 Update flow (`bin/omarchy-update`)
- Requires sudo-capable operations; sets up a sudo keepalive loop for the duration (revalidates timestamp every 60s) so long steps do not reprompt unexpectedly.
- Uses `script` logging to `/tmp/omarchy-update.log` and a lock (`omarchy-update-lock`) to prevent concurrent runs.
- Traps failures/interrupts/signals to stop stay-awake inhibitor and clean up authorization state; reports errors with support guidance.
- Performs preflight/free-space checks; `-y` skips start confirmation and can enable unattended mode.
- **Observed sequence (source):** `omarchy-update-pkg-prune` (before snapshot), `omarchy-snapshot create` (non-fatal except "no snapper config" handled distinctly), `omarchy-update-stay-awake start`, `omarchy-update-dev`, `omarchy-update-keyring`, `omarchy-update-system-pkgs` (blocking), optional shell restart if migrations pending, `omarchy-migrate`, `omarchy-update-orphan-pkgs -y`, log analysis, clear system-update indicator, `omarchy-update-restart --services-only`, `post-update` hook, `omarchy-update-mise` (best-effort), `omarchy-update-aur-pkgs`, `omarchy-update-boot` (must pass before completion/reboot), stop stay-awake, reboot prompt (`--reboot-only`) only after boot verification succeeds.

**Bottom fact:** Omarchy treats **boot verification as a hard gate** after package/migration steps; updates do not "finish" if boot artifacts fail verification.

### 2.5 Channel/platform management (`bin/omarchy-channel-set`)
- Supported channels: `stable|rc|edge|dev` (maps to pacman channels/packages; dev uses edge pacman channel + dev checkout linkage).
- Validates platform templates via `install/helpers/pacman.sh` before mutating state; refuses unsupported channel/platform combinations.
- `dev` channel: confirms intent, validates/uses `~/omarchy` checkout (`--filter=blob:none` clone if missing), checks required update support and templates/platform helpers, links checkout via `omarchy-dev-link`, sets reboot-required state, refreshes pacman, swaps packages with `pacman -S --needed --noconfirm --ask 4 ...`, handles leaving-dev unlink/PATH cleanup, then runs `omarchy-update -y` (interactive reboot prompt preserved).

### 2.6 Snapshots (`bin/omarchy-snapshot`)
- Thin wrapper over `snapper` configs (CSV-listed): requires at least one config or exits with guidance to configure snapper.
- `create`: creates numbered snapshots per config labeled with `omarchy-version` (fallback `unknown`) and runs cleanup; `restore`: delegates to `limine-snapper-restore`.

## 3. Robustness/error-proofing patterns (concrete)

- **Idempotent-by-marker migrations** with lock contention handling and strict shell mode.
- **Reboot-aware install sequencing** (enable services/configure firewall for next boot instead of mutating live installer environment in sensitive cases).
- **Update transaction discipline:** single lock, sudo keepalive, PTY logging, explicit ordering, service restart/hook phases, non-fatal optional steps where appropriate, and hard boot verification gate.
- **Platform/channel validation before mutation** (templates, checkout capabilities, supported platform/channel matrix).
- **Self-describing CLI with validation tooling** (`commands --check`, metadata parsing, route collision detection).

## 4. Limits/caveats for this Fedora dots repo

- Strongly Arch/pacman/Omarchy-path dependent (`/usr/share/omarchy`, pacman lock/snapper/limine/uwsm/sddm assumptions).
- Distro-scale scope and rapid churn; patterns should be adapted selectively, not copied wholesale.
- Some guarantees rely on Omarchy-owned tooling/packages unavailable on Fedora.

## 5. High-value borrowable facts for this repo

1. **Marker-based migrations** in state dir (simple, idempotent, auditable) for config/schema evolution.
2. **Explicit update/install phases with logs and pre/post checks** (and "do not claim success" gates for critical artifacts).
3. **Dry-run/check/help/summary UX** around install and maintenance commands.
4. **Enable-vs-start discipline** and environment-aware behavior (installer/live session/container/systemd availability checks).
5. **Metadata/consistency checks** for script interfaces where scale justifies it.

