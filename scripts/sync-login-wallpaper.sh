#!/usr/bin/env bash
# sync-login-wallpaper.sh — point the SDDM login + hyprlock lock screen at
# the desktop's current wallpaper.
#
# Resolves the live wallpaper the same way the shell does: quickshell's
# theme-state.json gives the theme + per-theme wallpaper index, and the
# file is the Nth sorted image in ~/Pictures/Themes/<theme>/ (list-themes.py
# sorts the same way). Copies it over sddm/sequoia/wallpaper.jpg, then
# reloads Hyprland so hyprlock.conf regenerates from hypr/hyprlock.lua.
#
# Afterwards push the login side system-wide (needs sudo):
#     ./scripts/install-sddm.sh --yes

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

IMG_EXTS="png jpg jpeg webp"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1" >&2; }
err()  { printf '\033[1;31mxx\033[0m %s\n' "$1" >&2; }

STATE="$(find "$HOME"/.local/state/quickshell/by-shell -maxdepth 2 -name theme-state.json -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)"
[ -n "$STATE" ] || { err "no quickshell theme-state.json — is the shell running?"; exit 1; }

WALL="$(python3 - "$STATE" <<'EOF'
import json, sys
from pathlib import Path
state = json.loads(Path(sys.argv[1]).read_text())
theme = state.get("theme", "")
idx = (state.get("wallpaperIndex") or {}).get(theme, 0)
d = Path.home() / "Pictures" / "Themes" / theme
exts = {".png", ".jpg", ".jpeg", ".webp"}
files = sorted(p for p in d.iterdir() if p.is_file() and p.suffix.lower() in exts)
if not files:
    sys.exit("no wallpapers in " + str(d))
print(files[max(0, min(idx, len(files) - 1))])
EOF
)"
[ -n "$WALL" ] || { err "could not resolve the current wallpaper"; exit 1; }

log "current wallpaper: $WALL"
cp "$WALL" "$REPO_DIR/sddm/sequoia/wallpaper.jpg"
log "copied -> sddm/sequoia/wallpaper.jpg"

if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 && log "hyprland reloaded (hyprlock.conf regenerated)"
else
    warn "hyprctl not found — run it yourself to regenerate hyprlock.conf"
fi

if ! grep -q "path = ~/.config/sddm/sequoia/wallpaper.jpg" "$HOME/.config/hypr/hyprlock.conf" 2>/dev/null; then
    warn "hyprlock.conf does not reference the shared wallpaper (check above)"
fi

echo
log "login side still needs a sudo push: ./scripts/install-sddm.sh --yes"
