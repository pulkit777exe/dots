#!/usr/bin/env bash
# install-sddm.sh — install the Sequoia SDDM theme system-wide and select it.
#
# The theme lives in the repo at sddm/sequoia (QML + wallpaper + avatar).
# SDDM runs as its own user and reads themes from /usr/share/sddm/themes,
# so this copies (never symlinks — /home is 700 and sddm couldn't follow
# a symlink into it) and writes /etc/sddm.conf.d/10-sequoia.conf.
# Needs sudo for the system paths only; run as your normal user.
#
#   ./scripts/install-sddm.sh [--yes] [--check] [--test]
#     --yes    skip the confirm prompt before sudo steps
#     --check  verify the install without changing anything
#     --test   launch sddm-greeter --test-mode after installing

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_DIR/sddm/sequoia"
DST="/usr/share/sddm/themes/sequoia"
CONF="/etc/sddm.conf.d/10-sequoia.conf"
ASSUME_YES=0
CHECK_ONLY=0
RUN_TEST=0

log()  { printf '\033[1;32m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1" >&2; }
err()  { printf '\033[1;31mxx\033[0m %s\n' "$1" >&2; }

for a in "$@"; do
    case "$a" in
        -y|--yes) ASSUME_YES=1 ;;
        --check) CHECK_ONLY=1 ;;
        --test) RUN_TEST=1 ;;
        -h|--help)
            echo "usage: install-sddm.sh [--yes] [--check] [--test]"
            exit 0 ;;
        *) err "unknown arg: $a"; exit 2 ;;
    esac
done

[ "$(id -u)" -eq 0 ] && { err "Run as your normal user, not root (sudo is used per-command)."; exit 1; }
[ -d "$SRC" ] || { err "theme source missing: $SRC"; exit 1; }
for f in Main.qml metadata.desktop theme.conf wallpaper.jpg avatar.jpg; do
    [ -f "$SRC/$f" ] || { err "missing $SRC/$f"; exit 1; }
done

check_state() {
    local rc=0
    echo
    log "checking SDDM sequoia install"
    [ -d "$DST" ] || { err "missing $DST"; rc=1; }
    for f in Main.qml metadata.desktop theme.conf wallpaper.jpg avatar.jpg; do
        [ -f "$DST/$f" ] && log "present: themes/sequoia/$f" || { err "missing: themes/sequoia/$f"; rc=1; }
    done
    if [ -f "$CONF" ] && grep -q "^Current=sequoia" "$CONF" 2>/dev/null; then
        log "theme selected in $CONF"
    else
        err "$CONF does not select Current=sequoia"; rc=1
    fi
    local face="/usr/share/sddm/faces/$USER.face.icon"
    if [ -f "$face" ]; then log "avatar: $face"; else warn "no $face — login still works, avatar falls back to bundled one"; fi
    if [ -f "$HOME/.config/sddm/sequoia/wallpaper.jpg" ]; then
        log "shared wallpaper: ~/.config/sddm/sequoia/wallpaper.jpg"
        if grep -q "path = ~/.config/sddm/sequoia/wallpaper.jpg" "$HOME/.config/hypr/hyprlock.conf" 2>/dev/null; then
            log "hyprlock uses the same wallpaper"
        else
            warn "hyprlock.conf does not point at the shared wallpaper — run ./install.sh (regenerates it from hypr/hyprlock.lua)"
        fi
    else
        warn "no ~/.config/sddm symlink — run ./install.sh --yes first (hyprlock reads the shared wallpaper through it)"
    fi
    if ls /usr/share/wayland-sessions/*.desktop >/dev/null 2>&1; then
        log "wayland sessions: $(ls /usr/share/wayland-sessions/*.desktop | xargs -n1 basename | tr '\n' ' ')"
    else
        err "no wayland sessions — nothing to log into"; rc=1
    fi
    if getent passwd "$USER" >/dev/null; then log "user $USER exists (uid $(id -u))"; else err "user $USER missing"; rc=1; fi
    if [ "$rc" -eq 0 ]; then log "check passed"; else err "check FAILED"; fi
    return "$rc"
}

if [ "$CHECK_ONLY" -eq 1 ]; then
    check_state
    exit $?
fi

if [ "$ASSUME_YES" -eq 0 ]; then
    echo
    warn "This will sudo-copy $SRC -> $DST and write $CONF."
    if [ ! -t 0 ]; then
        warn "no terminal to confirm on — re-run with --yes"
        exit 0
    fi
    printf '   Continue? [y/N] '
    reply=""; read -r reply || reply=""
    case "$reply" in [yY]|[yY][eE][sS]) ;; *) warn "aborted"; exit 0 ;; esac
fi

command -v sudo >/dev/null 2>&1 || { err "sudo not found"; exit 1; }

log "installing theme -> $DST"
sudo mkdir -p "$DST"
sudo cp -r "$SRC/." "$DST/"
sudo chmod 755 "$DST"
sudo chmod 644 "$DST"/Main.qml "$DST"/metadata.desktop "$DST"/theme.conf "$DST"/wallpaper.jpg "$DST"/avatar.jpg
# Strip group/other write so the greeter (and its file-watching) never
# trips over odd modes from the working tree.
sudo chmod go-w "$DST" "$DST"/*

log "selecting theme in $CONF"
sudo mkdir -p "$(dirname "$CONF")"
printf '[Theme]\nCurrent=sequoia\n' | sudo tee "$CONF" >/dev/null

# Avatars: the greeter runs as sddm and cannot read a 700 $HOME, so the
# world-readable FacesDir copy is the one that matters. Keep ~/.face.icon
# too for other greeters/apps that look there.
AV_SRC="$REPO_DIR/hypr/hyprlock/assets/avatar.jpeg"
if [ -f "$AV_SRC" ]; then
    log "installing avatar for $USER"
    sudo mkdir -p /usr/share/sddm/faces
    sudo cp "$AV_SRC" "/usr/share/sddm/faces/$USER.face.icon"
    sudo chmod 644 "/usr/share/sddm/faces/$USER.face.icon"
    cp "$AV_SRC" "$HOME/.face.icon" 2>/dev/null || warn "could not write ~/.face.icon"
else
    warn "no avatar at $AV_SRC — bundled avatar.jpg is used instead"
fi

# Fonts: the greeter cannot see ~/.local/share/fonts, so make the UI font
# visible system-wide when we have it. Missing SF Pro is non-fatal —
# fontconfig falls back and the layout is unchanged.
if [ -f "$HOME/.local/share/fonts/SF-Pro-Display-Regular.otf" ]; then
    log "publishing SF Pro Display system-wide for the greeter"
    sudo mkdir -p /usr/local/share/fonts/dots
    sudo cp "$HOME"/.local/share/fonts/SF-Pro-Display-*.otf /usr/local/share/fonts/dots/ 2>/dev/null || true
    sudo chmod 644 /usr/local/share/fonts/dots/* 2>/dev/null || true
    sudo fc-cache -f /usr/local/share/fonts/dots >/dev/null 2>&1 || true
else
    warn "SF Pro Display not in ~/.local/share/fonts — greeter falls back to system sans (install it once, see README > Fonts)"
fi

check_state || { err "installed with warnings — see above"; exit 1; }

if [ "$RUN_TEST" -eq 1 ]; then
    echo
    log "launching sddm-greeter --test-mode (close the window to finish)"
    sddm-greeter-qt6 --test-mode --theme "$DST"
fi

echo
log "done — reboot to see the real greeter. Verify anytime: ./scripts/install-sddm.sh --check"
