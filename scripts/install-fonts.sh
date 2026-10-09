#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FONT_SRC="$REPO_DIR/fonts"
FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1" >&2; }

have_font() { [ "$(fc-list 2>/dev/null | grep -ci "$1")" -gt 0 ]; }

if ! command -v fc-list >/dev/null 2>&1; then
    warn "fc-list not found — sudo dnf install fontconfig"
    exit 1
fi

mkdir -p "$FONT_DIR"

changed=0
for src in "$FONT_SRC"/*/*.ttf; do
    dst="$FONT_DIR/$(basename "$src")"
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        continue
    fi
    cp "$src" "$dst"
    changed=1
done

if [ "$changed" -eq 1 ]; then
    fc-cache -f >/dev/null
    log "installed vendored fonts into $FONT_DIR"
else
    log "vendored fonts already in place"
fi

missing=0
for fam in "JetBrainsMonoNL Nerd Font Mono" "Material Symbols Rounded"; do
    if have_font "$fam"; then
        log "font: $fam"
    else
        warn "$fam not visible to fontconfig — fc-cache -f, then re-run"
        missing=1
    fi
done

if have_font "SF Pro Display"; then
    log "font: SF Pro Display"
else
    warn "SF Pro Display cannot be vendored (Apple's license forbids redistribution)."
    warn "Once: download 'SF Pro' from https://developer.apple.com/fonts/, then copy"
    warn "  'SF Pro Display Regular.otf' and 'SF Pro Display Bold.otf' into $FONT_DIR"
    missing=1
fi

if [ "$missing" -eq 0 ]; then
    log "all fonts present"
fi
exit "$missing"
