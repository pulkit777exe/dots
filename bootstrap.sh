#!/usr/bin/env bash
# bootstrap.sh — one command to replicate this desktop on a fresh machine.
#
#     curl -fsSL https://raw.githubusercontent.com/pulkit777exe/dots/main/bootstrap.sh | bash
#
# Clones the repo (or reuses an existing clone), then runs install.sh to link
# every config unit into ~/.config. install.sh is idempotent, so re-running
# this is safe and is also how you update.
#
# ── Read this before running it on a machine you care about ──────────────
#
# This executes code fetched from a remote at the moment you run it. That is
# the same trust model as `curl | sh`, and it is the standard one for dotfiles
# — but it is not nothing. Concretely:
#
#   * Whoever controls the `pulkit777exe/dots` repository can run arbitrary
#     code as you. So can anyone who compromises that account.
#   * The default branch is mutable. A force-push, or a bad commit, changes
#     what the next person to run this gets.
#
# Mitigations this script applies:
#   * It never needs root. Nothing here uses sudo; it only writes inside
#     $HOME. Do not run it as root.
#   * It verifies the clone's `origin` actually points at the expected URL,
#     so a substituted or mistyped remote is caught.
#   * It refuses to run if your checkout has uncommitted local edits, so you
#     never execute a tree you did not intend to run.
#
# For a pinned, auditable install, check out a specific commit yourself and
# run install.sh from it — that removes the mutable-branch problem entirely:
#
#     git clone https://github.com/pulkit777exe/dots.git ~/dots
#     git -C ~/dots checkout <commit-or-tag>
#     ~/dots/install.sh --dry-run     # preview
#     ~/dots/install.sh
#
# See SECURITY.md for the full trust model and the audit summary.

set -euo pipefail

REPO_URL="${DOTS_REPO_URL:-https://github.com/pulkit777exe/dots.git}"
CLONE_DIR="${DOTS_DIR:-$HOME/dots}"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1" >&2; }
err()  { printf '\033[1;31mxx\033[0m %s\n' "$1" >&2; }
die()  { err "$1"; exit 1; }
# NOTE: these four duplicate scripts/lib.sh on purpose — this file is
# executed straight from its download URL (curl ... | bash) before any
# clone exists, so it cannot source the tree.

need() {
    command -v "$1" >/dev/null 2>&1 || die "$1 is required but not installed"
}

[ "$(id -u)" -eq 0 ] && die "Refusing to run as root. This only writes inside \$HOME; run it as your normal user."

# Handle -h/--help before touching the network or the filesystem, otherwise
# asking for help clones the repo as a side effect.
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            cat <<'USAGE'
usage: bootstrap.sh [--check] [--dry-run]

Clones/updates the dots repo into $DOTS_DIR (default ~/dots) and runs the
one-shot installer.

  -h, --help    show this message without cloning anything
  --check       verify an existing install without changing anything
  --dry-run     show the install plan without changing anything

Environment:
  DOTS_REPO_URL   override the repository URL
  DOTS_DIR        override the clone location
USAGE
            exit 0
            ;;
    esac
done

need git
need bash

if [ -d "$CLONE_DIR/.git" ]; then
    # Never execute a tree with uncommitted edits: that is how you end up
    # running something other than what the repo says.
    if [ -n "$(git -C "$CLONE_DIR" status --porcelain)" ]; then
        die "$CLONE_DIR has uncommitted local changes. Commit, stash, or clean them first — refusing to run an unverified tree."
    fi

    actual_origin="$(git -C "$CLONE_DIR" remote get-url origin 2>/dev/null || echo "<none>")"
    if [ "$actual_origin" != "$REPO_URL" ]; then
        die "origin mismatch in $CLONE_DIR
     expected: $REPO_URL
     actual:   $actual_origin
     Set DOTS_REPO_URL to match, or fix the remote. Refusing to continue."
    fi

    log "updating existing clone at $CLONE_DIR"
    git -C "$CLONE_DIR" pull --ff-only || die "pull is not fast-forward — $CLONE_DIR has local commits.
     Rebase them onto origin yourself (git -C $CLONE_DIR pull --rebase), then re-run."
else
    if [ -e "$CLONE_DIR" ]; then
        die "$CLONE_DIR already exists and is not a git clone.
     Move it aside, or set DOTS_DIR to a different path, then re-run."
    fi
    log "cloning $REPO_URL -> $CLONE_DIR"
    git clone "$REPO_URL" "$CLONE_DIR"

    # A clone can carry a different origin than requested (insteadOf rules,
    # a mirror, an env override). Confirm what we actually got.
    actual_origin="$(git -C "$CLONE_DIR" remote get-url origin 2>/dev/null || echo "<none>")"
    if [ "$actual_origin" != "$REPO_URL" ]; then
        die "clone origin does not match the requested URL
     expected: $REPO_URL
     actual:   $actual_origin
     Inspect $CLONE_DIR before using it."
    fi
fi

for arg in "$@"; do
    [ "$arg" = "--check" ] && CHECK_ONLY=1
    [ "$arg" = "--dry-run" ] && DRY_RUN=1
done

if [ "${CHECK_ONLY:-0}" -eq 1 ]; then
    log "verifying install"
    bash "$CLONE_DIR/install.sh" --check
else
    log "running one-shot install"
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        bash "$CLONE_DIR/install" --dry-run
    else
        bash "$CLONE_DIR/install"
    fi
fi

echo
log "done — log out, pick the Hyprland session, and log back in if needed"
log "verify with: $CLONE_DIR/install.sh --check"
