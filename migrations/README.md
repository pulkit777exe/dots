# Migrations

`scripts/migrate.sh` applies repo migrations **once per user**, in lexical order, and records completion markers in `$XDG_STATE_HOME/dots/migrations/<migration-file>`.

## Naming/versioning convention
- Use timestamped, sortable filenames: `YYYYMMDDHHMMSS_short-description.sh`
  - Example: `20261115120000_rename-legacy-state-paths.sh`
- Only executable-intended `*.sh` files in this directory are considered by the runner.
- Keep migrations small, focused, and ordered by filename.

## Authoring rules (wise practices)
- **Idempotent and safe:** migrations run once per marker, but should still be written defensively (check paths/state before changing).
- **No destructive deletes:** prefer moving aside with backups/suffixes or preserving user data.
- **User-scope only unless explicit:** avoid privileged/system changes unless absolutely necessary and clearly guarded.
- **Fail clearly:** `set -euo pipefail` and explicit checks; return non-zero on real failure so the marker is not written.
- **Respect dry-run context:** scripts may receive `DRY_RUN` in the environment from callers in future; prefer helper-aware behavior when added.

## Guard pattern examples
```bash
#!/usr/bin/env bash
set -euo pipefail

# Example guards
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# 1) Skip if target no longer relevant
[ -d "$CONFIG_HOME/some-old-dir" ] || exit 0

# 2) Move aside instead of deleting
ts="$(date +%Y%m%d-%H%M%S)"
mv "$CONFIG_HOME/some-old-dir" "$CONFIG_HOME/some-old-dir.pre-migrate.$ts"

# 3) Update files only when pattern exists
if [ -f "$CONFIG_HOME/example.conf" ] && grep -q 'oldKey' "$CONFIG_HOME/example.conf"; then
  sed -i 's/oldKey/newKey/g' "$CONFIG_HOME/example.conf"
fi
```

See `20260101000000_example-template.sh.example` for a starter template (not executed because it is not `*.sh`).
