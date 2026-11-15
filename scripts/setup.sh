#!/usr/bin/env bash
# setup.sh — provision a Fedora machine for this dots repo, then link it.
#
# Data-driven, phased provisioning via scripts/lib/{packages,provision}.sh.
# Idempotent: anything already present is skipped.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=0
ASSUME_YES=0
WANT_DESKTOP=0
WANT_SHELL=0
WANT_SESSION=0
WANT_NVIDIA=0
WANT_DEV=0
GROUPS_GIVEN=0
NO_LINK=0

# shellcheck disable=SC1091
. "$REPO_DIR/scripts/lib.sh"
# shellcheck disable=SC1091
. "$REPO_DIR/scripts/lib/logging.sh"
# shellcheck disable=SC1091
. "$REPO_DIR/scripts/lib/packages.sh"
# shellcheck disable=SC1091
. "$REPO_DIR/scripts/lib/provision.sh"

usage() {
    cat <<'USAGE'
usage: scripts/setup.sh [--dry-run] [--yes] [--all] [--desktop] [--shell]
                        [--session] [--nvidia] [--dev] [--no-link] [--list] [--help]

  --dry-run   print the plan without touching anything
  --yes       pass -y to dnf / copr and skip confirmations
  --all       install every group below
  --desktop   compositor, shell runtime, screenshot + media tools
  --shell     zsh, prompt, jumpers, oh-my-zsh, plugins, nvm
  --session   login session: sddm + sequoia theme, uwsm, graphical target, session checks
  --nvidia    RPM Fusion + akmod driver, CUDA, VA-API, envycontrol
  --dev       docker, kubectl, neovim, qmllint, lint tooling
  --no-link   packages only; skip the install.sh link step at the end
  --list      show the package groups and exit
  --help      show this message

With no group flag: --desktop --shell --session.
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        -y|--yes)  ASSUME_YES=1 ;;
        --all)     WANT_DESKTOP=1; WANT_SHELL=1; WANT_SESSION=1; WANT_NVIDIA=1; WANT_DEV=1; GROUPS_GIVEN=1 ;;
        --desktop) WANT_DESKTOP=1; GROUPS_GIVEN=1 ;;
        --shell)   WANT_SHELL=1; GROUPS_GIVEN=1 ;;
        --session) WANT_SESSION=1; GROUPS_GIVEN=1 ;;
        --nvidia)  WANT_NVIDIA=1; GROUPS_GIVEN=1 ;;
        --dev)     WANT_DEV=1; GROUPS_GIVEN=1 ;;
        --no-link) NO_LINK=1 ;;
        --list)    list_package_groups; exit 0 ;;
        -h|--help) usage; exit 0 ;;
        *)         err "unknown argument: $1"; usage >&2; exit 2 ;;
    esac
    shift
done

[ "$GROUPS_GIVEN" -eq 0 ] && { WANT_DESKTOP=1; WANT_SHELL=1; WANT_SESSION=1; }

DNF_YES=()
[ "$ASSUME_YES" -eq 1 ] && DNF_YES=(-y)

_run_name="setup"
[ "$DRY_RUN" -eq 1 ] && _run_name="setup-dry-run"
dots_init_logging "$_run_name"
trap dots_finish_run EXIT

provision_preflight
print_provision_summary

[ "$WANT_DESKTOP" -eq 1 ] && provision_desktop_group
[ "$WANT_SESSION" -eq 1 ] && provision_session_group
[ "$WANT_SHELL" -eq 1 ] && provision_shell_group
[ "$WANT_NVIDIA" -eq 1 ] && provision_nvidia_group
[ "$WANT_DEV" -eq 1 ] && provision_dev_group

provision_link_step
provision_login_theme

echo
log "setup done — verify with ./dots doctor and ./scripts/install-sddm.sh --check"

if [ "$WANT_NVIDIA" -eq 1 ] && [ "$DRY_RUN" -eq 0 ] \
    && lspci 2>/dev/null | grep -qi "nvidia"; then
    echo
    warn "NVIDIA driver installed or updated — reboot to load it."
    warn "On first driver install the akmods build can take a few minutes after boot."
fi
