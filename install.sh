#!/usr/bin/env bash

set -euo pipefail

# Bootstrap: find the root just well enough to source lib.sh; lib's
# repo_root() does the authoritative check right after.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || pwd)"
[ -d "$REPO_DIR/hypr" ] || REPO_DIR="$(pwd)"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DRY_RUN=0
CHECK_ONLY=0
ASSUME_YES=0

# shellcheck disable=SC1091
. "$REPO_DIR/scripts/lib.sh" 2>/dev/null || {
    printf 'xx install.sh: cannot load scripts/lib.sh\n' >&2
    exit 1
}

REPO_DIR="$(repo_root "$REPO_DIR" || true)"

UNITS=(colors hypr kitty quickshell sddm vlc Thunar)

# Repo-rel-source:home-rel-dest pairs for files linked into $HOME, not ~/.config.
HOME_FILES=(zsh/.zshrc:.zshrc)

# log/warn/err/run/confirm/backup_and_link come from scripts/lib.sh (sourced above).

usage() {
    cat <<'USAGE'
usage: install.sh [--dry-run] [--check] [--yes] [--help]

  --dry-run   print the plan without touching anything
  --check     only verify the installed config; make no changes
  --yes       do not prompt before moving an existing config aside
  --help      show this message

Moving an existing ~/.config/<unit> aside is always reversible — it is
renamed to <unit>.pre-install.<timestamp>, never deleted — but it is the
one step here that touches files this repo did not create, so it asks
first unless --yes is given. The same applies to files linked directly
into \$HOME (see HOME_FILES, e.g. ~/.zshrc).
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)   DRY_RUN=1 ;;
        --check)     CHECK_ONLY=1 ;;
        -y|--yes)    ASSUME_YES=1 ;;
        --full)      FULL_INSTALL=1 ;;
        -h|--help)   usage; exit 0 ;;
        *)           err "unknown argument: $1"; usage >&2; exit 2 ;;
    esac
    shift
done

check_bin() {
    local bin="$1" pkg_hint="$2" kind="${3:-required}"
    shift 3 2>/dev/null || shift $#
    local extra=("$@")

    local found=0 via=""
    if command -v "$bin" >/dev/null 2>&1; then
        found=1
    else
        local p
        for p in ${extra+"${extra[@]}"}; do
            if [ -x "$p" ]; then found=1; via="$p"; break; fi
        done
    fi

    if [ "$found" -eq 1 ]; then
        if [ -n "$via" ]; then
            log "found $bin (not on PATH: $via)"
        else
            log "found $bin"
        fi
        return 0
    fi

    if [ "$kind" = "optional" ]; then
        warn "$bin not found (optional) — $pkg_hint"
        MISSING_OPTIONAL+=("$bin")
    else
        err "$bin not found — $pkg_hint"
        MISSING+=("$bin")
    fi
    return 0
}

MISSING=()
MISSING_OPTIONAL=()

check_font() {
    local family="$1" what="$2" kind="${3:-required}"

    if ! command -v fc-list >/dev/null 2>&1; then
        warn "fc-list not found — sudo dnf install fontconfig (font checks skipped)"
        return 0
    fi

    if [ "$(fc-list 2>/dev/null | grep -ci "$family")" -gt 0 ]; then
        log "font: $family — $what"
        return 0
    fi

    if [ "$kind" = "optional" ]; then
        warn "font missing: $family (optional) — $what"
        MISSING_OPTIONAL+=("font:$family")
        return 0
    fi

    err "font missing: $family — $what"
    err "  run scripts/install-fonts.sh (SF Pro Display needs a one-time manual download; the script explains)"
    MISSING+=("font:$family")
    return 0
}

check_boot_session() {
    local rc=0
    if [ ! -d /run/systemd/system ] || ! command -v systemctl >/dev/null 2>&1; then
        warn "no systemd — skipping login-session checks"
        return 0
    fi

    echo
    log "verifying login session (DM, target, uwsm)"

    if [ "$(systemctl get-default 2>/dev/null)" = "graphical.target" ]; then
        log "systemd default target: graphical.target"
    else
        err "default target is $(systemctl get-default 2>/dev/null) — graphical login needs graphical.target (scripts/setup.sh --session)"
        rc=1
    fi

    local dm_ok=0 dm=""
    for dm in sddm gdm ly greetd; do
        if systemctl is-enabled --quiet "$dm" 2>/dev/null; then dm_ok=1; break; fi
    done
    if [ "$dm_ok" -eq 1 ]; then
        log "display manager enabled: $dm"
    else
        err "no display manager enabled (sddm/gdm/ly/greetd) — install + enable one (scripts/setup.sh --session)"
        rc=1
    fi

    if compgen -G "/usr/share/wayland-sessions/*.desktop" >/dev/null; then
        log "wayland session file(s) present"
    else
        err "no .desktop in /usr/share/wayland-sessions — nothing to pick at login"
        rc=1
    fi

    if command -v uwsm >/dev/null 2>&1; then
        if uwsm check may-start >/dev/null 2>&1; then
            log "uwsm check may-start: OK"
        elif [ -n "${WAYLAND_DISPLAY:-}" ] || [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
            warn "uwsm check may-start refuses inside a live graphical session — expected here, not a login problem"
        else
            err "uwsm check may-start failed — the session will not start (missing python3-pyxdg is the usual cause)"
            rc=1
        fi
    else
        err "uwsm not found — sudo dnf install uwsm (or run scripts/setup.sh --session)"
        rc=1
    fi

    if python3 -c 'import xdg' 2>/dev/null; then
        log "python3 xdg module: OK"
    else
        err "python3 -c 'import xdg' failed — sudo dnf install python3-pyxdg"
        rc=1
    fi

    return "$rc"
}

check_session() {
    local fail=0

    echo
    log "verifying installed config in $CONFIG_DIR"

    for u in "${UNITS[@]}"; do
        local dst="$CONFIG_DIR/$u"
        if [ ! -e "$dst" ]; then
            err "$u: not installed"
            fail=1
        elif [ -L "$dst" ]; then
            log "$u: linked -> $(readlink -f "$dst")"
        else
            warn "$u: real directory, not a symlink (run install.sh to take over)"
            fail=1
        fi
    done

    for f in "$CONFIG_DIR/quickshell/shell.qml" "$CONFIG_DIR/quickshell/modules/Keybinds.qml" \
             "$CONFIG_DIR/quickshell/modules/qmldir" "$CONFIG_DIR/hypr/hyprland.lua" \
             "$CONFIG_DIR/colors/index.json" "$CONFIG_DIR/kitty/kitty.conf"; do
        if [ -e "$f" ]; then
            log "present: ${f#"$CONFIG_DIR"/}"
        else
            err "missing: ${f#"$CONFIG_DIR"/}"
            fail=1
        fi
    done

    for pair in ${HOME_FILES+"${HOME_FILES[@]}"}; do
        dst="$HOME/${pair##*:}"
        if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$REPO_DIR/${pair%%:*}")" ]; then
            log "home: ${pair##*:} linked -> $(readlink -f "$dst")"
        elif [ -e "$dst" ]; then
            warn "home: ${pair##*:} exists but is not our symlink (run install.sh to take over)"
            fail=1
        else
            err "home: ${pair##*:} not installed"
            fail=1
        fi
    done

    if [ ! -e "$HOME/.zshrc.local" ]; then
        warn "home: .zshrc.local not present — secrets stay out of the repo; copy zsh/.zshrc.local.example there if you need API keys"
        if [ "$CHECK_ONLY" -eq 0 ] && [ "$DRY_RUN" -eq 0 ] && [ -f "$REPO_DIR/zsh/.zshrc.local.example" ]; then
            cp "$REPO_DIR/zsh/.zshrc.local.example" "$HOME/.zshrc.local"
            log "created ~/.zshrc.local from template"
        fi
    fi


    if [ -e "$CONFIG_DIR/colors/index.json" ]; then
        if command -v python3 >/dev/null 2>&1; then
            if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if isinstance(d.get("themes"), dict) else 1)' \
                "$CONFIG_DIR/colors/index.json" 2>/dev/null; then
                log "colors/index.json: theme catalog OK"
            else
                err "colors/index.json: 'themes' is not a key->metadata object; theme discovery will fail"
                fail=1
            fi
        fi
    fi

    if command -v qs >/dev/null 2>&1; then
        if ipc_show="$(qs -p "$CONFIG_DIR/quickshell" ipc show 2>/dev/null)" && [ -n "$ipc_show" ]; then
            missing_targets=""
            for t in shell uis auth; do
                if ! printf '%s\n' "$ipc_show" | grep -qx "target $t"; then
                    missing_targets="$missing_targets $t"
                fi
            done
            if [ -n "$missing_targets" ]; then
                err "qs ipc show: no target for$missing_targets -- every overlay will be unreachable"
                err "  Keybinds registers these. Check that shell.qml still references it:"
                err "  grep -n 'Keybinds' $CONFIG_DIR/quickshell/shell.qml"
                fail=1
            else
                n=$(printf '%s\n' "$ipc_show" | grep -c '^target ' || true)
                log "qs ipc show: shell + uis present ($n targets)"
            fi
        else
            warn "qs ipc show: no running instance -- skipping the IPC target check"
        fi
    else
        warn "qs not on PATH -- skipping the IPC target check"
    fi

    if command -v hyprctl >/dev/null 2>&1; then
        if binds="$(hyprctl globalshortcuts 2>/dev/null)"; then
            n=$(printf '%s\n' "$binds" | grep -c 'quickshell:' || true)
            if [ "$n" -eq 0 ]; then
                err "hyprctl globalshortcuts: no quickshell:* bindings -- the keybinds will not be loaded"
                fail=1
            else
                log "hyprctl globalshortcuts: $n quickshell:* binding(s)"
            fi
        else
            warn "hyprctl globalshortcuts failed -- skipping"
        fi
    else
        warn "hyprctl not on PATH -- skipping the globalshortcut check"
    fi

    if qs_bin="$(command -v quickshell)" && [ -n "$qs_bin" ]; then
        qtlib="$(ldd "$qs_bin" 2>/dev/null | grep -oE '/[^ ]*libQt6Core\.so\.[0-9]+' | head -1 || true)"
        if [ -n "$qtlib" ]; then
            case "$qtlib" in
                /usr/lib*|/lib*|/usr/bin/../lib*)
                    log "Qt6: resolves to system lib ($qtlib)"
                    ;;
                *)
                    warn "Qt6: $qtlib is outside the system library path --"
                    warn "  a bundled Qt may not match the system Qt6 your other apps use"
                    ;;
            esac
        fi
    fi

    if [ "${#MISSING[@]}" -gt 0 ]; then
        echo
        err "missing REQUIRED: ${MISSING[*]}"
        err "the desktop will not be whole until these are installed"
        fail=1
    fi
    if [ "${#MISSING_OPTIONAL[@]}" -gt 0 ]; then
        echo
        warn "missing optional (features degrade): ${MISSING_OPTIONAL[*]}"
    fi

    check_boot_session || fail=1

    local state_log="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/config-errors.log"
    if [ -s "$state_log" ]; then
        warn "hypr config errors logged (tail):"
        warn "$(tail -3 "$state_log")"
        warn "inspect + delete the log after fixing; a reload re-creates it on new failures"
    fi

    echo
    if [ "$fail" -eq 0 ]; then
        log "check passed"
    else
        err "check FAILED — see above"
    fi
    return "$fail"
}

main() {
    if [ "$(id -u)" -eq 0 ]; then
        err "Refusing to run as root."
        err "Run it as your normal user:  ./install.sh"
        err "(Under sudo, \$HOME is /root, so this would link /root/.config instead of yours.)"
        exit 1
    fi

    if [ -z "$REPO_DIR" ]; then
        err "cannot locate the repo root (no hypr/ and colors/ found)."
        err "Run this from a clone of the repo, or use ./bootstrap.sh."
        exit 1
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        log "dry run — no changes will be made"
    fi
    log "repo:    $REPO_DIR"
    log "target:  $CONFIG_DIR"

    if [ "$CHECK_ONLY" -eq 0 ]; then
        echo
        log "linking configs"
        for u in "${UNITS[@]}"; do
            backup_and_link "$REPO_DIR/$u" "$CONFIG_DIR/$u" || true
        done
        echo
        log "linking home files"
        for pair in ${HOME_FILES+"${HOME_FILES[@]}"}; do
            backup_and_link "$REPO_DIR/${pair%%:*}" "$HOME/${pair##*:}" || true
        done
    fi

    echo
    log "checking runtime dependencies (see README.md > needs)"
    echo
    log "required runtime"
    check_bin hyprland "sudo dnf copr enable nett00n/hyprland && sudo dnf install hyprland (or run scripts/setup.sh)"
    check_bin quickshell "sudo dnf copr enable nett00n/hyprland && sudo dnf install quickshell (or run scripts/setup.sh); must match this machine's Qt6 minor version, see README.md"
    check_bin kitty "sudo dnf install kitty"
    check_bin zsh "sudo dnf install zsh — the repo manages ~/.zshrc (see zsh/)"
    check_bin python3 "sudo dnf install python3"
    check_bin cliphist "sudo dnf install cliphist   (or: go install github.com/sentriz/cliphist@latest)"
    check_bin wl-copy "sudo dnf install wl-clipboard"
    check_bin hyprpaper "sudo dnf install hyprpaper — without it the wallpaper daemon never starts"
    check_bin hyprlock "sudo dnf install hyprlock — without it SUPER+L does nothing"
    check_bin hypridle "sudo dnf install hypridle — without it idleDPMS/idle actions never fire"
    check_bin grim "sudo dnf install grim — screenshot pipeline needs it"
    check_bin slurp "sudo dnf install slurp — region screenshots need it"
    check_bin thunar "sudo dnf install Thunar — file manager"
    check_bin gvfsd "sudo dnf install gvfs" required /usr/libexec/gvfsd
    check_bin xdg-desktop-portal-hyprland "sudo dnf install xdg-desktop-portal-hyprland — screen-share portal" required /usr/libexec/xdg-desktop-portal-hyprland
    check_bin xdg-desktop-portal-gtk "sudo dnf install xdg-desktop-portal-gtk — file-chooser portal" required /usr/libexec/xdg-desktop-portal-gtk
    check_bin polkitd "sudo dnf install polkit" required /usr/lib/polkit-1/polkitd /usr/libexec/polkitd
    check_bin hyprpolkitagent "sudo dnf install hyprpolkitagent (from the hyprland COPR) — without it pkexec/Thunar-mount prompts have no one to ask" required /usr/libexec/hyprpolkitagent

    echo
    log "optional (features degrade without them)"
    check_bin brightnessctl "sudo dnf install brightnessctl — XF86MonBrightness* keys"
    check_bin playerctl "sudo dnf install playerctl — XF86Audio* media keys"
    check_bin hyprsunset "blue-light filter; without it the control centre's Night Light toggle does nothing" optional
    check_bin starship "sudo dnf install starship — prompt in zsh/.zshrc degrades gracefully without it" optional
    check_bin zoxide "sudo dnf install zoxide — directory jumper in zsh/.zshrc degrades gracefully without it" optional

    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        warn "oh-my-zsh not found at ~/.oh-my-zsh — zsh/.zshrc prints a notice and continues; install from https://ohmyz.sh"
    fi

    if command -v zsh >/dev/null 2>&1 && [ "${SHELL:-}" != "$(command -v zsh)" ]; then
        warn "login shell is ${SHELL:-unknown}, not zsh — the managed ~/.zshrc only applies to zsh sessions (scripts/setup.sh --shell offers chsh)"
    fi

    if [ "$CHECK_ONLY" -eq 0 ]; then
        echo
        log "installing vendored fonts"
        run "$REPO_DIR/scripts/install-fonts.sh" || warn "font install incomplete — SF Pro Display is the usual reason (see above)"
    fi

    echo
    log "checking fonts"
    check_font "SF Pro Display" "UI text; until installed Qt falls back to fontconfig substitution" optional
    check_font "JetBrainsMonoNL Nerd Font Mono" "kitty + lock-screen wifi glyph"
    check_font "Material Symbols Rounded" "shell icon glyphs"
    check_font "Apple Color Emoji" "emoji; ./dots packages --desktop installs the latest Fedora RPM" optional

    if [ "$CHECK_ONLY" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
        echo
        log "generating derived state (palette outputs + hyprlock.conf)"
        if command -v python3 >/dev/null 2>&1; then
            run python3 "$CONFIG_DIR/quickshell/scripts/list-themes.py" >/dev/null || warn "list-themes.py failed — run it by hand"
            run python3 "$CONFIG_DIR/quickshell/scripts/publish-colors.py" || warn "publish-colors.py failed — run it by hand"
            run python3 "$CONFIG_DIR/quickshell/scripts/generate-hypridle-conf.py" || warn "generate-hypridle-conf.py failed — run it by hand"
            run python3 "$CONFIG_DIR/quickshell/scripts/generate-hypr-conf.py" || warn "generate-hypr-conf.py failed — run it by hand"
        fi
        if command -v lua >/dev/null 2>&1; then
            run lua "$CONFIG_DIR/hypr/hyprlock.lua" || warn "hyprlock.conf not generated — run it by hand"
        else
            warn "lua not found — hyprlock.conf not generated (sudo dnf install lua)"
        fi
    fi

    local cs=0
    check_session || cs=$?

    echo
    if [ "$CHECK_ONLY" -eq 1 ]; then
        log "done (check only)"
    else
        log "done — log out, select the Hyprland session, and log back in"
    fi

    if [ "$cs" -ne 0 ]; then
        err "finished with errors — see above"
        return "$cs"
    fi
    return 0
}

main "$@"
