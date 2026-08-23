#!/usr/bin/env bash
# Restores Island config from a backup tarball.
#
# Usage: restore-island.sh <path-to-backup.tar.gz>
#   Extracts the backup over the current config dirs.
#   Prompts before overwriting. Run backup-island.sh first!
set -euo pipefail

backup="${1:?usage: restore-island.sh <path-to-backup.tar.gz>}"

if [[ ! -f "$backup" ]]; then
    echo "restore-island: file not found: $backup" >&2
    exit 1
fi

echo "restore-island: will restore from $backup"
echo "  Affected paths:"
tar tzf "$backup" | head -20
echo ""

read -rp "Overwrite current config? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "restore-island: aborted"
    exit 0
fi

tar xzf "$backup" -C /
echo "restore-island: restored. Restart quickshell: pkill quickshell && qs -c ~/.config/quickshell/shell.qml &"
