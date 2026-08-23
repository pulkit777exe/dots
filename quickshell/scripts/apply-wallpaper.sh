#!/usr/bin/env bash
# Sets the desktop wallpaper via swaybg. Wallpapers are theme-scoped assets
# (see themes/*.json "wallpapers" array) and never change the active
# palette -- picking a new wallpaper within a theme is purely cosmetic.
#
# Usage: apply-wallpaper.sh <path-to-image>
set -euo pipefail

wallpaper="${1:?usage: apply-wallpaper.sh <path-to-image>}"
[[ -f "$wallpaper" ]] || { echo "island: wallpaper not found: $wallpaper" >&2; exit 1; }

pkill -x swaybg >/dev/null 2>&1 || true
setsid swaybg -i "$wallpaper" -m fill >/dev/null 2>&1 &
disown
echo "island: wallpaper set to $wallpaper"
