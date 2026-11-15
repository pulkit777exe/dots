#!/usr/bin/env bash

set -euo pipefail

# Bootstrap: find the root just well enough to source libs.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || pwd)"
[ -d "$REPO_DIR/hypr" ] || REPO_DIR="$(pwd)"

DRY_RUN=0
CHECK_ONLY=0
ASSUME_YES=0
FULL_INSTALL=0

# shellcheck disable=SC1091
. "$REPO_DIR/scripts/lib.sh" 2>/dev/null || {
    printf 'xx install.sh: cannot load scripts/lib.sh\n' >&2
    exit 1
}

REPO_DIR="$(repo_root "$REPO_DIR" || true)"

# shellcheck disable=SC1091
. "$REPO_DIR/scripts/lib/manifest.sh"
# shellcheck disable=SC1091
. "$REPO_DIR/scripts/lib/deploy.sh"
# shellcheck disable=SC1091
. "$REPO_DIR/scripts/lib/generate.sh"
# shellcheck disable=SC1091
. "$REPO_DIR/scripts/lib/checks.sh"

CONFIG_DIR="$(dots_config_dir)"

MISSING=()
MISSING_OPTIONAL=()

usage() {
    cat <<'USAGE'
usage: install.sh [--dry-run] [--check] [--yes] [--help]

  --dry-run   print the plan without touching anything
  --check     only verify the installed config; make no changes
  --yes       do not prompt before moving an existing config aside
  --help      show this message

Managed configs/home files are linked idempotently. Existing targets are
moved aside to *.pre-install.<timestamp> (never deleted). Generated runtime
state and repo migrations are applied during normal installs.
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)   DRY_RUN=1 ;;
        --check)     CHECK_ONLY=1 ;;
        -y|--yes)    ASSUME_YES=1 ;;
        --full)      FULL_INSTALL=1 ;;
        -h|--help)   usage; exit 0 ;;
        *)           err "unknown argument: $1"; usage >&2; exit 2 ;;
    esac
    shift
done

main() {
    local cs=0

    if [ "$(id -u)" -eq 0 ]; then
        err "Refusing to run as root."
        err "Run it as your normal user:  ./install.sh"
        err "(Under sudo, \$HOME is /root, so this would link /root/.config instead of yours.)"
        exit 1
    fi

    if [ -z "$REPO_DIR" ]; then
        err "cannot locate the repo root (no hypr/ and colors/ found)."
        err "Run this from a clone of the repo, or use ./bootstrap.sh."
        exit 1
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        log "dry run — no changes will be made"
    fi
    log "repo:    $REPO_DIR"
    log "target:  $CONFIG_DIR"

    if [ "$CHECK_ONLY" -eq 0 ]; then
        deploy_configs "$REPO_DIR" "$CONFIG_DIR"
    fi

    echo
    phase "verify: dependencies and runtime"
    check_runtime_dependencies

    if [ "$CHECK_ONLY" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
        echo
        log "installing vendored fonts"
        run "$REPO_DIR/scripts/install-fonts.sh" || warn "font install incomplete — SF Pro Display is the usual reason (see above)"
    fi

    check_fonts

    if [ "$CHECK_ONLY" -eq 0 ]; then
        run_apply_phase "$REPO_DIR" "$DRY_RUN"
    fi

    check_installed_layout "$REPO_DIR" "$CONFIG_DIR" "$CHECK_ONLY" "$DRY_RUN" || cs=1
    check_live_integrations || cs=1

    echo
    if [ "$cs" -eq 0 ]; then
        log "check passed"
    else
        err "check FAILED — see above"
    fi

    if [ "$CHECK_ONLY" -eq 1 ]; then
        log "done (check only)"
    else
        log "done — log out, select the Hyprland session, and log back in"
    fi

    if [ "$cs" -ne 0 ]; then
        err "finished with errors — see above"
        return "$cs"
    fi
    return 0
}

main "$@"
