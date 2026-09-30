#!/usr/bin/env bash
# Quickshell / Hyprland Recovery Utility
# Usage: ./recovery.sh [backup|restore|reset|reload]

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
BACKUP_DIR="$STATE_DIR/backups"

mkdir -p "$BACKUP_DIR"

case "${1:-status}" in
    backup)
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        DEST="$BACKUP_DIR/backup_$TIMESTAMP"
        mkdir -p "$DEST"
        cp -rf "$STATE_DIR"/*.json "$DEST/" 2>/dev/null || true
        echo "State backed up to: $DEST"
        ;;
    restore)
        LATEST=$(ls -td "$BACKUP_DIR"/backup_* 2>/dev/null | head -n 1)
        if [ -n "$LATEST" ]; then
            cp -rf "$LATEST"/*.json "$STATE_DIR/" 2>/dev/null || true
            echo "State restored from: $LATEST"
        else
            echo "No backup found in $BACKUP_DIR"
        fi
        ;;
    reset)
        rm -f "$STATE_DIR"/*.json 2>/dev/null || true
        echo "Reset state files to defaults."
        ;;
    reload)
        echo "Reloading Hyprland and restarting Quickshell..."
        if command -v hyprctl >/dev/null 2>&1; then
            hyprctl reload
        fi
        pkill -x quickshell 2>/dev/null || true
        sleep 1
        # setsid, not a bare &: a backgrounded child of this script gets
        # SIGHUP when the script's terminal goes away, so the shell would
        # die the moment the user closed the window that started recovery.
        setsid quickshell -p "$CONFIG_DIR" >/dev/null 2>&1 < /dev/null &
        # Confirm it came up rather than reporting success unconditionally.
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            sleep 1
            if pgrep -x quickshell >/dev/null 2>&1; then
                # The IpcHandlers only register once Keybinds is constructed,
                # so this is the check that says the shell is actually usable.
                if command -v qs >/dev/null 2>&1 \
                   && qs -p "$CONFIG_DIR" ipc show 2>/dev/null | grep -qx "target uis"; then
                    echo "Quickshell restarted, shell + uis targets registered."
                else
                    echo "Quickshell restarted, but the uis target is not up yet."
                fi
                exit 0
            fi
        done
        echo "Quickshell did not come up within 10s -- check the log." >&2
        exit 1
        ;;
    *)
        echo "Quickshell Recovery Tool"
        echo "Usage: $0 {backup|restore|reset|reload}"
        ;;
esac
