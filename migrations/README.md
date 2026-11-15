# Migrations

Timestamped or ordered `*.sh` scripts applied once per user by `scripts/migrate.sh`.
Markers are stored in `$XDG_STATE_HOME/dots/migrations/`.
Migrations must be idempotent and safe to re-run conceptually, but are executed only when unmarked.
