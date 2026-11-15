#!/usr/bin/env bash
# lib.sh — shared helpers for the dots entry points. Source, do not execute.
#
#   . "$REPO_DIR/scripts/lib.sh"
#
# Contract: callers typically set REPO_DIR, DRY_RUN (0/1), ASSUME_YES (0/1),
# and CHECK_ONLY (0/1) before calling helpers that act. Helpers read them at
# call time, so sourcing order does not matter.
[ -n "${DOTS_LIB_LOADED:-}" ] && return 0
DOTS_LIB_LOADED=1

have() { command -v "$1" >/dev/null 2>&1; }

# repo_root [START_DIR] — print the repo root (dir containing hypr/ + colors/).
repo_root() {
    local dir="${1:-}"
    if [ -z "$dir" ] && [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
        dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        [ "$(basename "$dir")" = "scripts" ] && dir="$(dirname "$dir")"
    fi
    [ -z "$dir" ] && dir="$(pwd)"
    if [ -d "$dir/hypr" ] && [ -d "$dir/colors" ]; then
        printf '%s\n' "$dir"
        return 0
    fi
    return 1
}

# require_tty — abort when an interactive prompt would hang (pipe/cron/CI).
require_tty() {
    if [ "${ASSUME_YES:-0}" -eq 0 ] && [ ! -t 0 ]; then
        die "No terminal to confirm on. Re-run with --yes."
    fi
}

log()  { printf '\033[1;32m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1" >&2; }
err()  { printf '\033[1;31mxx\033[0m %s\n' "$1" >&2; }
info() { printf '   %s\n' "$1"; }
phase(){ printf '\n\033[1;36m::\033[0m %s\n' "$1"; }
die()  { err "$1"; exit 1; }
run()  { if [ "${DRY_RUN:-0}" -eq 1 ]; then printf '   would run: %s\n' "$*"; else "$@"; fi; }

dots_state_dir() { printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/dots"; }
dots_migration_dir() { printf '%s\n' "$(dots_state_dir)/migrations"; }
dots_log_dir() { printf '%s\n' "$(dots_state_dir)/logs"; }

# Bounded summary counters (best-effort; callers may increment).
: "${DOTS_WARN_COUNT:=0}"
: "${DOTS_ERR_COUNT:=0}"
note_warn() { DOTS_WARN_COUNT=$((DOTS_WARN_COUNT + 1)); warn "$1"; }
note_err()  { DOTS_ERR_COUNT=$((DOTS_ERR_COUNT + 1)); err "$1"; }

summary_line() {
    printf '  %s\n' "$1"
}

# confirm PROMPT -> exit 0 on an explicit yes. Refuses without a terminal
# instead of hanging a pipe, cron job or CI run.
confirm() {
    if [ ! -t 0 ]; then
        err "no terminal to confirm on."
        return 1
    fi
    printf '   %s [y/N] ' "$1"
    local reply=""
    read -r reply || reply=""
    case "$reply" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# backup_and_link SRC DST — point DST at SRC via symlink. Anything already
# at DST that is not our symlink is renamed to
# <dst>.pre-install.<timestamp>: moved aside, never deleted. Prompts first
# unless ASSUME_YES=1; dry-run prints the plan and changes nothing.
backup_and_link() {
    local src="$1" dst="$2"
    local name
    name="$(basename "$dst")"

    if [ ! -e "$src" ] && [ ! -L "$src" ]; then
        warn "skipping $name — not present in the repo"
        return 0
    fi

    if [ -d "$src" ] && [ -z "$(ls -A "$src" 2>/dev/null)" ]; then
        err "skipping $name — $src exists but is empty"
        return 1
    fi

    if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
        log "$name already linked"
        return 0
    fi

    if [ -e "$dst" ] || [ -L "$dst" ]; then
        local backup
        backup="$dst.pre-install.$(date +%Y%m%d-%H%M%S)"

        if [ "${DRY_RUN:-0}" -eq 1 ]; then
            warn "$dst exists and isn't our symlink — would move it to $backup"
        elif [ "${ASSUME_YES:-0}" -eq 0 ]; then
            warn "$dst exists and isn't our symlink."
            if ! confirm "Move it to $backup ?"; then
                warn "left $dst alone"
                return 0
            fi
            mv "$dst" "$backup"
        else
            warn "$dst exists and isn't our symlink — moving it to $backup"
            mv "$dst" "$backup"
        fi
    fi

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        log "$name would be linked -> $dst"
    else
        mkdir -p "$(dirname "$dst")"
        ln -s "$(readlink -f "$src")" "$dst"
        log "linked $name -> $dst"
    fi
}
