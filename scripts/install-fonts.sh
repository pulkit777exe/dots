#!/usr/bin/env bash

set -euo pipefail

FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
JB_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
MS_URL="https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1" >&2; }

missing=0

have_font() { [ "$(fc-list 2>/dev/null | grep -ci "$1")" -gt 0 ]; }

need_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        warn "$1 not found — sudo dnf install $1"
        exit 1
    fi
}

install_jb() {
    log "installing JetBrainsMono Nerd Font (NL + regular, all weights)"
    local tmp
    tmp="$(mktemp -d)"
    curl -fsSL "$JB_URL" -o "$tmp/jb.zip"
    unzip -o -q "$tmp/jb.zip" -d "$FONT_DIR"
    rm -rf "$tmp"
}

install_ms() {
    log "installing Material Symbols Rounded (variable font)"
    curl -fsSL "$MS_URL" -o "$FONT_DIR/MaterialSymbolsRounded.ttf"
}

sf_pro_manual() {
    warn "SF Pro Display cannot be auto-installed (Apple's license requires an"
    warn "explicit download). Once:)"
    warn "  1. download 'SF Pro' from https://developer.apple.com/fonts/"
    warn "  2. copy 'SF Pro Display Regular.otf' and 'SF Pro Display Bold.otf' to $FONT_DIR"
}

if ! command -v fc-list >/dev/null 2>&1; then
    warn "fc-list not found — sudo dnf install fontconfig"
    exit 1
fi

mkdir -p "$FONT_DIR"
need_cmd curl
need_cmd unzip

changed=0
if have_font "JetBrainsMonoNL Nerd Font Mono"; then
    log "JetBrainsMonoNL Nerd Font Mono: already installed"
else
    install_jb
    changed=1
fi

if have_font "Material Symbols Rounded"; then
    log "Material Symbols Rounded: already installed"
else
    install_ms
    changed=1
fi

if [ "$changed" -eq 1 ]; then
    fc-cache -f >/dev/null
fi

if have_font "SF Pro Display"; then
    log "SF Pro Display: already installed"
else
    sf_pro_manual
    missing=1
fi

for fam in "JetBrainsMonoNL Nerd Font Mono" "Material Symbols Rounded"; do
    if ! have_font "$fam"; then
        warn "$fam still not visible to fontconfig — fc-cache -f, then re-run"
        missing=1
    fi
done

if [ "$missing" -eq 0 ]; then
    log "all fonts present"
fi
exit "$missing"
