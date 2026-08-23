#!/usr/bin/env bash
# Persists a chrome metric (bar-height or font-size). Deliberately separate
# from island-set-theme.sh: metrics are Island chrome dimensions, not part of
# a theme's identity, and must never touch hyprlock's color file.
#
# Usage: island-set-metric.sh <bar-height|font-size> <pixels>
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/island"
STATE_FILE="$STATE_DIR/theme.json"

metric="${1:?usage: island-set-metric.sh <bar-height|font-size> <pixels>}"
value="${2:?missing pixel value}"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/island"
mkdir -p "$STATE_DIR" "$CACHE_DIR/tmp"
[[ -f "$STATE_FILE" ]] || echo '{"active":"catppuccin-mocha","barHeight":37,"fontSize":15}' > "$STATE_FILE"

case "$metric" in
    bar-height) key="barHeight" ;;
    font-size)  key="fontSize" ;;
    *) echo "island: unknown metric '$metric' (expected bar-height|font-size)" >&2; exit 1 ;;
esac

tmp="$(mktemp "$CACHE_DIR/tmp/island-metric.XXXXXXXXXX")"
jq --argjson v "$value" ".$key = \$v" "$STATE_FILE" > "$tmp"
mv "$tmp" "$STATE_FILE"
echo "island: $metric set to ${value}px"
