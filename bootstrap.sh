#!/usr/bin/env bash
# bootstrap.sh — one command to replicate this desktop on a fresh machine.
#
#     curl -fsSL https://raw.githubusercontent.com/pulkit777exe/dots/main/bootstrap.sh | bash
#
# Clones the repo (or reuses an existing clone), then runs install.sh to link
# every config unit into ~/.config. install.sh is idempotent, so re-running
# this is safe and is also how you update.

set -euo pipefail

REPO_URL="${DOTS_REPO_URL:-https://github.com/pulkit777exe/dots.git}"
CLONE_DIR="${DOTS_DIR:-$HOME/dots}"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1" >&2; }
err()  { printf '\033[1;31mxx\033[0m %s\n' "$1" >&2; }

need() {
    command -v "$1" >/dev/null 2>&1 || { err "$1 is required but not installed"; exit 1; }
}

need git
need bash

if [ -d "$CLONE_DIR/.git" ]; then
    log "updating existing clone at $CLONE_DIR"
    git -C "$CLONE_DIR" pull --ff-only
else
    if [ -e "$CLONE_DIR" ]; then
        err "$CLONE_DIR already exists and is not a git clone."
        err "Move it aside, or set DOTS_DIR to a different path, then re-run."
        exit 1
    fi
    log "cloning $REPO_URL -> $CLONE_DIR"
    git clone "$REPO_URL" "$CLONE_DIR"
fi

log "installing configs"
bash "$CLONE_DIR/install.sh" "$@"

echo
log "next: log out, pick the Hyprland session, log back in"
log "then verify with: $CLONE_DIR/install.sh --check"
