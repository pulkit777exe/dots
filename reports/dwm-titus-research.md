# dwm-titus — Deep Research Report (bottom-facts update)

**Repo:** https://github.com/ChrisTitusTech/dwm-titus  
**Default branch:** `main`  
**Homepage/docs:** https://dwm.christitus.com  
**License:** MIT  
**Research date:** 2026-11-15 (live GitHub API + raw source inspection)

## 1. Verified project facts

- **Identity/scope:** Fedora-only, keyboard-driven X11 desktop project centered on `dwm` with a managed userland (Quickshell UI, installers, update/diagnostics tooling, ISO/release pipeline). Not a generic cross-distro dotfiles repo.
- **Activity (GitHub API snapshot):** stars ~481; forks ~116; open issues 2; watchers ~481; created 2023-05-30; pushed 2026-11-09; updated 2026-11-13; default branch `main`; wiki/pages enabled; discussions disabled.
- **Latest release:** `v0.8.0` (2026-11-05, "Fedora 45") with standard/NVIDIA ISOs, source/runtime archives, `SHA256SUMS`, manifests, build notes, publication verification artifacts.
- **Process/docs signals:** `.github/workflows/c-cpp.yml`, `codeql.yml`, `docs.yaml`, Dependabot; `README.md`, `SPEC.md`, `ROADMAP.md`, `TASKS.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `AGENTS.md`, extensive `docs/`.
- **Release qualification (v0.8.0, from `docs/RELEASE-0.8.0.md`):** Fedora 45 Server Network Install 1.4 x86_64 images; Fedora 44 retained for existing-system install/source updates; Fedora 45 image notes include NetworkManager-wifi/wpa_supplicant/wireless-regdb, Thunar on F45, omission of unavailable/retired optional packages; qualification/provenance recorded (build source/commit refs, GPG/signature metadata, verification checks, VM UEFI/BIOS/manual-start checks, NVIDIA image caveat/limitation notes).

## 2. Installer and package/profile model (source-verified)

### 2.1 `install.sh` (existing-system installer)
- **Fedora-only guardrails:** reads `/etc/os-release`, requires `ID=fedora`, computes release version and enforces supported range (`MIN_SUPPORTED_FEDORA_VERSION=44`, `MAX_SUPPORTED_FEDORA_VERSION`/env-aware).
- **Profiles/options:** `--profile core|recommended|full` (default from `DWM_INSTALL_PROFILE` or `full`), `--non-interactive`, `--yes`, `--dry-run`, `--install-herdr|--skip-herdr`, `--install-ai-agent NAME`, `--skip-ai-agent`, `--enable-gaming-repo` (saves choice to user config).
- **Summary-first UX:** prints profile, Fedora version, package group sizes (dnf/core/recommended/full), Flatpak/runtime extras, optional agent/Herdr/gaming decisions, dry-run note, config preservation note; interactive runs prompt for confirmation unless `--yes/--non-interactive`.
- **Defensive behavior:** command/dependency checks (`dnf`, git/build deps via package resolver), optional-feature availability checks with warnings/skips, dry-run short-circuits execution paths while preserving intent reporting.
- **Post-install/session concerns (observed in script):** builds/installs via `make`, installs package groups/profile extras, configures timesync helper, display-manager/session assets, terminal selection, default app seeding, Quickshell/picom/font/theme compatibility checks, optional Herdr/AI-agent flows, preserves user-owned config while seeding managed defaults.

### 2.2 `scripts/dwm-packages.sh` (capability/package map)
- Centralizes Fedora package capability mapping used by installers/diagnostics:
  - `provider-policy`: virtual capability alternatives (e.g. `ppd-service` -> `power-profiles-daemon` or alternative command presence; `xserver` -> `xorg-x11-server-Xorg` or `Xorg`/`Xlibre`).
  - `build`, `ci-smoke`, `base`, `common`, `core`, `recommended`, `full`, `optional-agent-*` package groups.
- Release-aware image override: `dwm_fedora_release()` prefers `DWM_IMAGE_FEDORA_RELEASE`, then `VERSION_ID`.
- Fedora-version conditionals: e.g. `common` adds `thunar` for F45+, keeps `upower`; `recommended`/`full` gate optional packages (timeshift, `libxcrypt-compat` depending on release, GTK themes removed on newer Fedora where unavailable).
- **Bottom fact:** package selection is profile- and release-aware, with provider/capability abstractions to tolerate packaging differences.

### 2.3 `scripts/configure-timesync.sh` (installer-only, Fedora)
- Sources shared utils, exits non-zero on non-Fedora.
- Preserves existing time-sync providers if enabled/active (when manager state query is meaningful): `chronyd`, `chronyd-restricted`, `ntpd`, `ntpsec`, `openntpd`.
- If `systemd-timesyncd.service` is masked/alias, leaves it unchanged; otherwise enables and (when not in offline/systemctl-limited context) starts it idempotently.
- **Bottom fact:** installer avoids introducing a second clock-discipline service and is safe to rerun in image/chroot/installed contexts.

## 3. Managed install, receipts, and dev synchronization (source-verified)

### 3.1 `Makefile` install/managed-tree model
- Installs system binaries/helpers, session/desktop/systemd/polkit assets, and managed user data/config trees under XDG paths (`XDG_DATA_HOME/dwm-titus`, config/state dirs) with explicit ownership handling (`OWNER`, `USER_HOME`, `XDG_*` overrides).
- `make install` performs complete system + user install flow (build prerequisites satisfied by targets), creates required runtime/state directories, installs managed assets (`system/usr-share`, `system/data`, `system/config`, helper scripts/commands), and records install receipt state under managed data/state paths.
- `make install-receipt` writes a machine-readable receipt/manifest metadata for the managed install (used by update/verify flows).
- Uninstall paths distinguish managed install artifacts from user-owned config where applicable.
- **Bottom fact:** dwm-titus treats installation as a **managed tree with receipt/manifest awareness**, not ad-hoc file copies.

### 3.2 `scripts/dev-sync-install.sh`
- Purpose: build and synchronize current checkout with live managed install, or verify parity (`--check`).
- Validates live roots/paths as absolute and safe for the active environment; uses Makefile path variables (`PREFIX`, `MANPREFIX`, `XSESSIONSDIR`, `DATADIR`, `USER_HOME`, `XDG_*`).
- Default flow: clean/build `dwm`, compare managed files against live install and skip reinstall when already matching, back up current managed installation before update, run full system+user Makefile install, verify installed commands/generated files/managed data/Quickshell, restart Quickshell when safe or defer to required session restart, report whether `dwm` restart is required.
- `--check` mode performs parity/runtime verification without building or mutating files.
- **Bottom fact:** dev/install sync is receipt-aware, backup-before-mutate, and explicitly distinguishes live-restartable UI components from session-restart-required core WM changes.

## 4. Desktop update engine and runtime operations (`scripts/dwm-desktop-update`)

This is a large Python control-plane (not a thin shell wrapper) for source updates, state, privileged actions, and GUI-facing operations.

### 4.1 State, locking, and status model
- Uses durable state/status tracking with phased operation states: `starting`, `downloading`, `dependencies`, `building`, `backing-up`, `installing`, `verifying`, `activating`, `recovering` (and terminal/error states outside active set).
- Employs file locking (`fcntl`) and controlled temp/work dirs for transactional steps; guards against concurrent/invalid operations.
- Maintains operation metadata/log context and emits structured status suitable for GUI/CLI consumers; supports status inspection and journal/log retrieval patterns.

### 4.2 Update/install transaction behavior
- Fetches/builds from source checkout/release context, resolves dependencies, backs up managed install before applying changes, installs/verifies/activates with rollback/recovery handling on failure paths.
- Coordinates managed receipt/state updates and user/runtime follow-up (e.g. Quickshell restart when safe; session restart signaling when required).
- Integrates with systemd unit context (`dwm-desktop-update.service` references in script) for background/privileged execution and progress reporting.

### 4.3 Privileged helper and journal/status patterns
- Separates privileged operations behind controlled helper execution paths (polkit/pkexec/systemd-mediated patterns in codebase) rather than embedding unrestricted root actions in UI flows.
- Captures command results/return codes and preserves logs/status for diagnostics (`dwm-diagnostics`/GUI can inspect operation state and journal output).
- **Bottom fact:** updates are implemented as **transactional, observable operations** with explicit phases, lock/state management, backup/verify/activate sequencing, and privileged-boundary handling.

## 5. Settings/runtime helper architecture (repo-wide pattern)

- `scripts/` contains many narrowly scoped providers/helpers (display/input/appearance/picom/panel/personalization, Quickshell control/state/network, diagnostics, migrations, release/image tooling), indicating decomposition by responsibility.
- Settings flows separate interactive/UI state from privileged persistence/application via dedicated helpers/providers (including root-helper paths for system-affecting changes).
- Migrations exist for evolving user-facing config/state (examples named in repo/scripts listings), consistent with preserving user setups across upgrades.

## 6. Robustness and error-proofing patterns (concrete)

- **Strict platform targeting + release/version awareness:** Fedora-only checks and release-conditioned package/capability logic reduce unsupported-state drift.
- **Installer safety UX:** profile/summary/dry-run/non-interactive/confirmation controls and optional-component graceful degradation.
- **Managed install integrity:** receipt/manifest-aware installs, parity checks (`--check`), backup-before-update, verify-after-install.
- **Transactional updates:** phased state machine, locking, durable status/logs, recovery paths, restart requirements surfaced explicitly.
- **Privilege separation:** privileged persistence/update actions isolated from UI scripts.
- **Release engineering discipline:** reproducible artifacts/checksums/manifests/build notes/publication verification and hardware qualification notes.
- **User-config preservation:** managed defaults seeded while user-owned/local config and existing service providers (e.g. timesync) are preserved when appropriate.

## 7. Limits/caveats (for this repo)

- X11/dwm + project-specific helper/layout assumptions (`dwm-*`, Makefile/XDG-managed tree, Quickshell control plane) are not directly portable to Hyprland/Wayland.
- Operational surface is large; adopting wholesale would conflict with this dots repo's simplification goal.
- Some guarantees depend on Fedora/systemd/polkit/PackageKit and dwm-titus-specific managed install receipts.

## 8. High-value borrowable facts for this Fedora Hyprland dots repo

1. **Profiled install + summary + dry-run/check parity mode** (`install.sh`/`dev-sync-install.sh` patterns) for safe, auditable changes.
2. **Release-aware capability/package mapping** (`dwm-packages.sh`) instead of hardcoded package assumptions where Fedora variants/providers differ.
3. **Managed-vs-user-owned boundaries with receipts/parity checks** to detect drift and avoid clobbering local config.
4. **Transactional update semantics at small scale:** backup, apply, verify, report restart requirements, and preserve logs/status.
5. **Privilege isolation for system mutations** (narrow helpers/services) and installer-only system integration scripts (e.g. timesync) that preserve existing providers.
6. **Explicit qualification/recovery documentation mindset** (what was tested, caveats, verification commands/artifacts) even for a smaller dots project.

## 9. Bottom line

dwm-titus is a strong Fedora-native example of **managed desktop lifecycle engineering**: profile-aware installation, receipt/parity-driven sync, transactional updates with observable state and privileged boundaries, and disciplined release verification. Its X11/dwm stack is different, but its operational patterns are directly relevant to hardening a one-shot, idempotent Hyprland + Quickshell Fedora dots setup without overcomplicating it.
