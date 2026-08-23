#!/usr/bin/env bash
# Bridges a Hyprland keybind to the running Quickshell instance's IpcHandler
# (target "island", see shell.qml). Isolated to one script so the actual IPC
# invocation only needs updating in one place if it changes between
# Quickshell versions.
#
# Usage: island-dispatch.sh <expanded|launcher|theme|wallpaper|settings|power>
set -euo pipefail

action="${1:?usage: island-dispatch.sh <expanded|launcher|theme|wallpaper|settings|power>}"

case "$action" in
    expanded|launcher|theme|wallpaper|settings|power) ;;
    *) echo "island: unknown dispatch action '$action'" >&2; exit 1 ;;
esac

qs ipc call island "$action"
