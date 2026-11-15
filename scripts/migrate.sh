#!/usr/bin/env bash
# Apply repo migrations once per user (marker-based, idempotent).
# Migrations live in $REPO_DIR/migrations/*.sh and run in lexical order.
# Completion markers are stored in $XDG_STATE_HOME/dots/migrations/.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=0
PENDING_ONLY=0

# shellcheck disable=SC1091
. "$REPO_DIR/scripts/lib.sh" 2>/dev/null || {
    printf 'xx migrate.sh: cannot load scripts/lib.sh\n' >&2
    exit 1
}

usage() {
    cat <<'USAGE'
usage: scripts/migrate.sh [--dry-run] [--pending]

  --dry-run  show pending migrations without applying them
  --pending  list pending migrations and exit 0 if any, 1 if none
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --pending|--check) PENDING_ONLY=1 ;;
        -h|--help) usage; exit 0 ;;
        *) err "unknown argument: $1"; usage >&2; exit 2 ;;
    esac
    shift
done

MIGRATIONS_DIR="$REPO_DIR/migrations"
STATE_DIR="$(dots_migration_dir)"

[ -d "$MIGRATIONS_DIR" ] || exit 0
mkdir -p "$STATE_DIR" 2>/dev/null || true

pending=()
for f in "$MIGRATIONS_DIR"/*.sh; do
    [ -e "$f" ] || continue
    name="$(basename "$f")"
    marker="$STATE_DIR/$name"
    [ -f "$marker" ] && continue
    pending+=("$f")
done

if [ "$PENDING_ONLY" -eq 1 ]; then
    if [ "${#pending[@]}" -gt 0 ]; then
        printf '%s\n' "${pending[@]##*/}"
        exit 0
    fi
    exit 1
fi

[ "${#pending[@]}" -eq 0 ] && { [ "$DRY_RUN" -eq 1 ] && log "migrations: none pending"; exit 0; }

for f in "${pending[@]}"; do
    name="$(basename "$f")"
    marker="$STATE_DIR/$name"
    if [ "$DRY_RUN" -eq 1 ]; then
        log "would apply migration: $name"
        continue
    fi
    log "applying migration: $name"
    # Run in a subshell with repo context; fail closed per migration.
    (
        export REPO_DIR DRY_RUN
        # shellcheck disable=SC1090
        bash -euo pipefail "$f"
    )
    : > "$marker"
done
