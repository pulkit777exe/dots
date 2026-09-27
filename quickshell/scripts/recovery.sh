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
        sleep 0.5
        quickshell -p "$CONFIG_DIR/shell.qml" &
        echo "Quickshell restarted."
        ;;
    *)
        echo "Quickshell Recovery Tool"
        echo "Usage: $0 {backup|restore|reset|reload}"
        ;;
esac
