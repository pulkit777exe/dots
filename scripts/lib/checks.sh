#!/usr/bin/env bash
# Verification/check logic for install and doctor flows.

# shellcheck shell=bash

: "${MISSING:=()}"
: "${MISSING_OPTIONAL:=()}"

check_bin() {
    local bin="$1" pkg_hint="$2" kind="${3:-required}"
    shift 3 2>/dev/null || shift $#
    local extra=("$@")

    local found=0 via="" p
    if command -v "$bin" >/dev/null 2>&1; then
        found=1
    else
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

check_core_services() {
    local rc=0 svc
    if [ ! -d /run/systemd/system ] || ! command -v systemctl >/dev/null 2>&1; then
        warn "no systemd — skipping service checks"
        return 0
    fi
    echo
    log "verifying core services (actionable)"
    for svc in NetworkManager.service upower.service power-profiles-daemon.service bluetooth.service; do
        if ! systemctl list-unit-files "$svc" >/dev/null 2>&1; then
            info "service not installed/present: $svc (optional depending on hardware)"
            continue
        fi
        if systemctl is-enabled --quiet "$svc" 2>/dev/null || systemctl is-active --quiet "$svc" 2>/dev/null; then
            log "service ok: $svc ($(systemctl is-enabled "$svc" 2>/dev/null || echo unknown)/$(systemctl is-active "$svc" 2>/dev/null || echo unknown))"
        else
            warn "service not enabled/active: $svc — enable with: sudo systemctl enable --now $svc"
        fi
    done
    for svc in pipewire.socket pipewire-pulse.socket wireplumber.service; do
        if ! systemctl --user list-unit-files "$svc" >/dev/null 2>&1; then
            info "user service not present: $svc (audio stack may differ)"
            continue
        fi
        if systemctl --user is-enabled --quiet "$svc" 2>/dev/null || systemctl --user is-active --quiet "$svc" 2>/dev/null; then
            log "user service ok: $svc"
        else
            warn "user service not enabled/active: $svc — enable with: systemctl --user enable --now $svc"
        fi
    done
    return "$rc"
}

check_boot_session() {
    local rc=0 dm dm_ok
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
    dm_ok=0; dm=""
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

check_runtime_dependencies() {
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
    check_bin hyprpolkitagent "optional fallback polkit agent" optional /usr/libexec/hyprpolkitagent
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
}

check_fonts() {
    echo
    log "checking fonts"
    check_font "SF Pro Display" "UI text; until installed Qt falls back to fontconfig substitution" optional
    check_font "JetBrainsMonoNL Nerd Font Mono" "kitty + lock-screen wifi glyph"
    check_font "Material Symbols Rounded" "shell icon glyphs"
    check_font "Apple Color Emoji" "emoji; ./dots packages --desktop installs the latest Fedora RPM" optional
}

check_installed_layout() {
    local repo_dir="${1:?repo_dir required}" config_dir="${2:?config_dir required}" check_only="${3:-0}" dry_run="${4:-0}"
    local fail=0 u f dst pair state_home runtime_hypr runtime_idle runtime_lock pending_migs

    echo
    log "verifying installed config in $config_dir"
    for u in "${DOTS_CONFIG_UNITS[@]}"; do
        dst="$config_dir/$u"
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

    while IFS= read -r f; do
        [ -n "$f" ] || continue
        if [ -e "$f" ]; then
            log "present: ${f#"$config_dir"/}"
        else
            err "missing: ${f#"$config_dir"/}"
            fail=1
        fi
    done < <(dots_required_runtime_files)

    for pair in ${DOTS_HOME_FILES+"${DOTS_HOME_FILES[@]}"}; do
        dst="$HOME/${pair##*:}"
        if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$repo_dir/${pair%%:*}")" ]; then
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
        if [ "$check_only" -eq 0 ] && [ "$dry_run" -eq 0 ] && [ -f "$repo_dir/zsh/.zshrc.local.example" ]; then
            cp "$repo_dir/zsh/.zshrc.local.example" "$HOME/.zshrc.local"
            log "created ~/.zshrc.local from template"
        fi
    fi

    if [ -e "$config_dir/colors/index.json" ] && command -v python3 >/dev/null 2>&1; then
        if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if isinstance(d.get("themes"), dict) else 1)' \
            "$config_dir/colors/index.json" 2>/dev/null; then
            log "colors/index.json: theme catalog OK"
        else
            err "colors/index.json: 'themes' is not a key->metadata object; theme discovery will fail"
            fail=1
        fi
    fi

    state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
    runtime_hypr="$state_home/quickshell/hypr.lua"
    runtime_idle="$config_dir/hypr/hypridle.conf"
    runtime_lock="$config_dir/hypr/hyprlock.conf"
    if [ -s "$runtime_hypr" ]; then log "generated: $runtime_hypr"; else warn "generated runtime file missing: $runtime_hypr (run ./install or ./dots link/apply flow)"; fail=1; fi
    if [ -s "$runtime_idle" ]; then log "generated: $runtime_idle"; else warn "generated runtime file missing: $runtime_idle"; fail=1; fi
    if [ -s "$runtime_lock" ]; then log "generated: $runtime_lock"; else warn "generated runtime file missing: $runtime_lock"; fi
    if [ -d "$state_home/dots/migrations" ]; then log "state dir: $state_home/dots/migrations"; fi
    if [ -x "$repo_dir/scripts/migrate.sh" ] || [ -f "$repo_dir/scripts/migrate.sh" ]; then
        if pending_migs="$(bash "$repo_dir/scripts/migrate.sh" --pending 2>/dev/null)"; then
            if [ -n "$pending_migs" ]; then
                warn "pending migrations:"
                printf '%s\n' "$pending_migs" | sed 's/^/   - /' >&2
            fi
        fi
    fi
    return "$fail"
}

check_live_integrations() {
    local fail=0 config_dir ipc_show missing_targets n binds qs_bin qtlib state_log
    config_dir="$(dots_config_dir)"

    if command -v qs >/dev/null 2>&1; then
        if ipc_show="$(qs -p "$config_dir/quickshell" ipc show 2>/dev/null)" && [ -n "$ipc_show" ]; then
            missing_targets=""
            for t in shell uis auth; do
                if ! printf '%s\n' "$ipc_show" | grep -qx "target $t"; then
                    missing_targets="$missing_targets $t"
                fi
            done
            if [ -n "$missing_targets" ]; then
                err "qs ipc show: no target for$missing_targets -- every overlay will be unreachable"
                err "  Keybinds registers these. Check that shell.qml still references it:"
                err "  grep -n 'Keybinds' $config_dir/quickshell/shell.qml"
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

    if qs_bin="$(command -v quickshell 2>/dev/null || true)" && [ -n "$qs_bin" ]; then
        qtlib="$(ldd "$qs_bin" 2>/dev/null | grep -oE '/[^ ]*libQt6Core\.so\.[0-9]+' | head -1 || true)"
        if [ -n "$qtlib" ]; then
            case "$qtlib" in
                /usr/lib*|/lib*|/usr/bin/../lib*) log "Qt6: resolves to system lib ($qtlib)" ;;
                *) warn "Qt6: $qtlib is outside the system library path --"; warn "  a bundled Qt may not match the system Qt6 your other apps use" ;;
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

    check_core_services || fail=1
    check_boot_session || fail=1

    state_log="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/config-errors.log"
    if [ -s "$state_log" ]; then
        warn "hypr config errors logged (tail):"
        warn "$(tail -3 "$state_log")"
        warn "inspect + delete the log after fixing; a reload re-creates it on new failures"
    fi

    return "$fail"
}

run_checks() {
    local repo_dir="${1:?repo_dir required}" config_dir="${2:?config_dir required}" check_only="${3:-0}" dry_run="${4:-0}"
    check_runtime_dependencies
    if [ "$check_only" -eq 0 ] && [ "$dry_run" -eq 0 ]; then
        echo
        log "installing vendored fonts"
        run "$repo_dir/scripts/install-fonts.sh" || warn "font install incomplete — SF Pro Display is the usual reason (see above)"
    fi
    check_fonts
    check_installed_layout "$repo_dir" "$config_dir" "$check_only" "$dry_run"
    check_live_integrations
}
