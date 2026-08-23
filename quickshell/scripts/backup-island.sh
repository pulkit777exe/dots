#!/usr/bin/env bash
# Snapshots all Island-related config and state to ~/backups/.
# Keeps the 5 most recent backups, deletes older ones.
#
# Usage: backup-island.sh
#   No arguments — backs up everything automatically.
set -euo pipefail

BACKUP_DIR="${HOME}/backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/island-${TIMESTAMP}.tar.gz"
KEEP=5

mkdir -p "$BACKUP_DIR"

# Build list of paths to snapshot (only those that exist)
paths=()
for p in \
    "$HOME/.config/hypr/hyprland.conf" \
    "$HOME/.config/hypr/hyprlock.conf" \
    "$HOME/.config/quickshell" \
    "$HOME/.local/state/island" \
    "$HOME/.cache/island"; do
    [[ -e "$p" ]] && paths+=("$p")
done

if [[ ${#paths[@]} -eq 0 ]]; then
    echo "backup-island: nothing to back up" >&2
    exit 1
fi

tar czf "$BACKUP_FILE" "${paths[@]}"
echo "backup-island: created $BACKUP_FILE"

# Prune old backups, keep last $KEEP
count=$(ls -1 "$BACKUP_DIR"/island-*.tar.gz 2>/dev/null | wc -l)
if (( count > KEEP )); then
    ls -1t "$BACKUP_DIR"/island-*.tar.gz | tail -n +$((KEEP + 1)) | xargs rm -f
    echo "backup-island: pruned old backups, keeping last $KEEP"
fi
