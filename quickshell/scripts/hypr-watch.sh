#!/usr/bin/env bash
# Tails Hyprland's event socket (socket2) so HyprlandService.qml can react to
# window/workspace changes live instead of polling. Requires `socat`
# (dnf install socat). If unavailable, HyprlandService still works via its own
# periodic poll fallback -- this is a latency improvement, not a hard
# dependency for correctness.
set -euo pipefail

SOCK="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"

if [[ ! -S "$SOCK" ]]; then
    echo "hypr-watch: socket not found: $SOCK" >&2
    exit 1
fi

if ! command -v socat >/dev/null 2>&1; then
    echo "hypr-watch: socat not installed, no live event stream (falling back to poll)" >&2
    exit 1
fi

exec socat -u UNIX-CONNECT:"$SOCK" -
