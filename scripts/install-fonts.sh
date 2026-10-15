#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FONT_SRC="$REPO_DIR/fonts"
FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"

# shellcheck disable=SC1091
. "$REPO_DIR/scripts/lib.sh"

have_font() { [ "$(fc-list 2>/dev/null | grep -ci "$1")" -gt 0 ]; }

if ! command -v fc-list >/dev/null 2>&1; then
    warn "fc-list not found — sudo dnf install fontconfig"
    exit 1
fi

mkdir -p "$FONT_DIR"

# Extra font files may be passed as arguments (e.g. SF Pro Display .otf
# files from Apple, which cannot be vendored): they are copied into the
# font dir before the checks run.
for f in "$@"; do
    if [ -f "$f" ]; then
        case "$f" in
            *.otf|*.OTF|*.ttf|*.TTF)
                cp "$f" "$FONT_DIR/"
                log "installed $(basename "$f") from argument"
                ;;
            *) warn "ignoring $f — not a font file" ;;
        esac
    else
        warn "ignoring $f — no such file"
    fi
done

changed=0
for src in "$FONT_SRC"/*/*.ttf; do
    [ -e "$src" ] || continue
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
    warn "Once: download 'SF Pro' from https://developer.apple.com/fonts/, then either"
    warn "  copy 'SF Pro Display Regular.otf' and 'SF Pro Display Bold.otf' into $FONT_DIR,"
    warn "  or pass them directly: scripts/install-fonts.sh ~/Downloads/*.otf"
    warn "Until then the shell renders with fontconfig substitution (--check treats it as optional)."
    missing=1
fi

if [ "$missing" -eq 0 ]; then
    log "all fonts present"
fi
exit "$missing"
