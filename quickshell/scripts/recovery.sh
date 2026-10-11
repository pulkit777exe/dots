#!/usr/bin/env bash
# Quickshell / Hyprland Recovery Utility
# Usage: ./recovery.sh [backup|restore|reset|stop|reload]

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
BACKUP_DIR="$STATE_DIR/backups"

mkdir -p "$BACKUP_DIR"

# Stop the shell without leaking its watchers.
#
# Three of the services spawn a watcher that outlives the shell's exit:
# Clipboard's `wl-paste --watch cliphist store`, Wifi's `nmcli monitor`,
# and PowerProfile's `powerprofilesctl monitor`. Quickshell does not take
# those down when it exits -- they are reparented to init and keep running.
#
# That is invisible until it is not. Each restart left one more of each
# behind, so 42 stale `wl-paste --watch` processes were holding the
# clipboard watch open while the live one also watched it. The symptom
# was the clipboard history staying empty with no error anywhere:
# cliphist had 750 entries on disk and the service's own list was
# always [].
#
# PowerProfile's is the odd one out and is listed for a different reason:
# `powerprofilesctl monitor` is not a subcommand, so it exits 2 on a
# usage error within milliseconds and cannot pile up the way the other
# two do. It is reaped anyway because the shell can still die inside
# that window, and because keeping this list identical to the set of
# processes the services start is what stops it drifting into fiction --
# an earlier version of this list named a `bluetoothctl monitor` that
# the service never spawned.
#
# So: SIGTERM first and wait for a real exit, so the shell gets to close
# its own pipes, and only then kill whatever is still holding a watch.
# A bare `pkill` skips the graceful part and orphans them faster.
stop_shell() {
    if pgrep -x quickshell >/dev/null 2>&1; then
        pkill -TERM -x quickshell 2>/dev/null || true
        for _ in $(seq 1 20); do
            pgrep -x quickshell >/dev/null 2>&1 || break
            sleep 0.25
        done
        pkill -KILL -x quickshell 2>/dev/null || true
        sleep 0.5
    fi

    local left=0
    for pat in "wl-paste --watch cliphist" "nmcli monitor" "powerprofilesctl monitor"; do
        # Only processes reparented to init, i.e. left behind by a shell
        # that has already exited. Never touch a live one.
        for pid in $(pgrep -f "$pat" 2>/dev/null); do
            if [ "$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')" = "1" ]; then
                kill -TERM "$pid" 2>/dev/null && left=$((left + 1))
            fi
        done
    done
    [ "$left" -gt 0 ] && sleep 0.5
    for pat in "wl-paste --watch cliphist" "nmcli monitor" "powerprofilesctl monitor"; do
        for pid in $(pgrep -f "$pat" 2>/dev/null); do
            if [ "$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')" = "1" ]; then
                kill -KILL "$pid" 2>/dev/null || true
            fi
        done
    done

    if [ "$left" -gt 0 ]; then
        echo "  reaped $left orphaned watcher(s) from a previous run"
    fi
}

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
    stop)
        stop_shell
        ;;
    reload)
        echo "Reloading Hyprland and restarting Quickshell..."
        if command -v hyprctl >/dev/null 2>&1; then
            hyprctl reload
        fi
        # Daemons are ensured, never restarted: a blind restart kills the
        # wallpaper and the idle timers for no reason. They ship systemd
        # user units (same ones modules/startup.lua enables), so ensure
        # them through systemctl rather than pgrep/setsid.
        for daemon in hyprpaper hypridle; do
            if ! command -v "$daemon" >/dev/null 2>&1; then
                echo "  $daemon not installed, skipping" >&2
            elif command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
                systemctl --user enable --now "$daemon.service" \
                    && echo "  $daemon ensured via user unit" \
                    || echo "  $daemon unit failed, skipping" >&2
            elif pgrep -x "$daemon" >/dev/null 2>&1; then
                echo "  $daemon already running"
            else
                setsid "$daemon" >/dev/null 2>&1 < /dev/null &
                echo "  started missing $daemon"
            fi
        done
        # Quickshell goes last: restarting it drops the global shortcuts
        # for ~2s and kills in-flight IPC, so everything cheaper happens
        # first. hyprlock and polkitd are deliberately never touched here.
        stop_shell
        # setsid, not a bare &: a backgrounded child of this script gets
        # SIGHUP when the script's terminal goes away, so the shell would
        # die the moment the user closed the window that started recovery.
        setsid quickshell -p "$CONFIG_DIR" >/dev/null 2>&1 < /dev/null &
        # Confirm it came up rather than reporting success unconditionally.
        # The process existing is not enough: the IpcHandlers only register
        # once Keybinds is constructed, and "Not ready to accept queries
        # yet." mid-startup is retryable (same tolerance as tests/run.sh).
        started=$SECONDS
        while [ $((SECONDS - started)) -lt 15 ]; do
            if pgrep -x quickshell >/dev/null 2>&1 \
                && command -v qs >/dev/null 2>&1 \
                && qs -p "$CONFIG_DIR" ipc show 2>/dev/null | grep -qx "target uis"; then
                echo "Quickshell restarted, shell + uis targets registered."
                exit 0
            fi
            sleep 0.5
        done
        echo "Quickshell did not register the uis target within 15s -- check the log." >&2
        exit 1
        ;;
    *)
        echo "Quickshell Recovery Tool"
        echo "Usage: $0 {backup|restore|reset|stop|reload}"
        ;;
esac
