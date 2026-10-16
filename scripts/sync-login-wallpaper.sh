#!/usr/bin/env bash
# sync-login-wallpaper.sh — point the SDDM login + hyprlock lock screen at
# the desktop's current wallpaper.
#
# Resolves the live wallpaper the same way the shell does: quickshell's
# theme-state.json gives the theme + per-theme wallpaper index, and the
# file is picked from list-themes.py's discovery output (sorted the same
# way the picker lists them). Single source of truth — no second sort here.
# Copies it over sddm/sequoia/wallpaper.jpg, then reloads Hyprland so
# hyprlock.conf regenerates from hypr/hyprlock.lua.
#
# Afterwards push the login side system-wide (needs sudo):
#     ./scripts/install-sddm.sh --yes

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_DIR/scripts/lib.sh"

STATE="$(find "$HOME"/.local/state/quickshell/by-shell -maxdepth 2 -name theme-state.json -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)"
[ -n "$STATE" ] || { err "no quickshell theme-state.json — is the shell running?"; exit 1; }

WALL="$(python3 - "$STATE" "$REPO_DIR/quickshell/scripts/list-themes.py" <<'EOF'
import json, subprocess, sys
from pathlib import Path
try:
    state = json.loads(Path(sys.argv[1]).read_text())
    theme = state.get("theme", "")
    idx = (state.get("wallpaperIndex") or {}).get(theme, 0)
    out = subprocess.run([sys.executable, sys.argv[2]],
                         capture_output=True, text=True, check=True)
    walls = json.loads(out.stdout)["themes"][theme]["wallpapers"]
    if not walls:
        sys.exit("no wallpapers for theme " + theme)
    print(walls[max(0, min(idx, len(walls) - 1))])
except Exception as e:
    sys.exit(f"could not resolve the current wallpaper: {e}")
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
