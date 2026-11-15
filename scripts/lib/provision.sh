#!/usr/bin/env bash
# Provisioning phases for Fedora setup (packages, services, session, shell, extras).

# shellcheck shell=bash

provision_preflight() {
    [ "$(id -u)" -eq 0 ] && die "Refusing to run as root. Run as your normal user; sudo is used per-command."
    [ -f /etc/fedora-release ] || die "This provisions Fedora (dnf). Detected: $(uname -s)."
    command -v dnf >/dev/null 2>&1 || die "dnf not found."
    command -v sudo >/dev/null 2>&1 || die "sudo not found."
    if ! command -v curl >/dev/null 2>&1; then
        if [ "${DRY_RUN:-0}" -eq 1 ]; then
            log "would run: sudo dnf install curl"
        else
            require_tty
            sudo dnf install "${DNF_YES[@]}" curl
        fi
    fi
}

print_provision_summary() {
    echo
    log "install summary"
    printf '  mode: %s\n' "$([ "${DRY_RUN:-0}" -eq 1 ] && echo dry-run || echo apply)"
    printf '  groups:'
    [ "${WANT_DESKTOP:-0}" -eq 1 ] && printf ' desktop'
    [ "${WANT_SHELL:-0}" -eq 1 ] && printf ' shell'
    [ "${WANT_SESSION:-0}" -eq 1 ] && printf ' session'
    [ "${WANT_NVIDIA:-0}" -eq 1 ] && printf ' nvidia'
    [ "${WANT_DEV:-0}" -eq 1 ] && printf ' dev'
    printf '\n'
    printf '  link/config: %s\n' "$([ "${NO_LINK:-0}" -eq 1 ] && echo skip || echo yes)"
    echo
}

ensure_apple_emoji_font() {
    local pkg="$APPLE_EMOJI_PKG"
    if pkg_installed "$pkg"; then
        log "$pkg already installed ($(rpm -q --qf '%{VERSION}-%{RELEASE}' "$pkg"))"
        return 0
    fi
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        log "would run: curl -fL $APPLE_EMOJI_RPM_URL -> temp"
        log "would run: sudo dnf install <rpm>  # $pkg"
        return 0
    fi
    if [ "${ASSUME_YES:-0}" -eq 0 ] && [ ! -t 0 ]; then
        warn "no terminal for the sudo prompt — skipping Apple Color Emoji"
        warn "  re-run interactively, or pass --yes (with cached/NOPASSWD sudo)"
        return 0
    fi
    local tmp rc=0
    tmp="$(mktemp -d)"
    log "downloading the latest Apple Color Emoji RPM (~110 MB)"
    if curl -fL --retry 3 --progress-bar "$APPLE_EMOJI_RPM_URL" -o "$tmp/$pkg.rpm"; then
        log "installing $pkg from the latest upstream release"
        sudo dnf install "${DNF_YES[@]}" "$tmp/$pkg.rpm" || rc=$?
    else
        rc=1
    fi
    rm -rf "$tmp"
    if [ "$rc" -ne 0 ]; then
        warn "Apple Color Emoji install failed — fetch the RPM later from"
        warn "  https://github.com/samuelngs/apple-emoji-ttf/releases"
        return 0
    fi
    local ver
    ver="$(rpm -q --qf '%{VERSION}-%{RELEASE}' "$pkg" 2>/dev/null || true)"
    log "installed $pkg${ver:+ ($ver)}"
}

ensure_pam_keyring() {
    local pam=/etc/pam.d/sddm
    if [ ! -f "$pam" ]; then
        warn "no $pam — skipping keyring PAM setup"
        return 0
    fi
    if grep -q "pam_gnome_keyring\.so" "$pam"; then
        log "sddm PAM already unlocks the keyring"
        return 0
    fi
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        log "would run: add pam_gnome_keyring auth+session lines to $pam (with backup)"
        return 0
    fi
    require_tty
    log "enabling keyring unlock in $pam"
    sudo cp "$pam" "$pam.pre-dots-$(date +%Y%m%d-%H%M%S)"
    echo "-auth      optional      pam_gnome_keyring.so" | sudo tee -a "$pam" >/dev/null
    echo "-session   optional      pam_gnome_keyring.so auto_start" | sudo tee -a "$pam" >/dev/null
}

ensure_charge_helper() {
    local node="" src dst rules want1 want2 tmp
    for f in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
        [ -e "$f" ] && { node="$f"; break; }
    done
    if [ -z "$node" ]; then
        log "no charge-control node — skipping charge-limit helper"
        return 0
    fi
    src="$REPO_DIR/quickshell/scripts/set-charge-limit.sh"
    dst=/usr/local/bin/dots-set-charge-limit
    rules=/etc/sudoers.d/dots-charge-limit
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        log "would run: install $dst (root-owned) + $rules for $USER"
        return 0
    fi
    if [ ! -f "$src" ]; then
        warn "missing $src — skipping charge-limit helper"
        return 0
    fi
    require_tty
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        log "charge-limit helper already installed"
    else
        log "installing charge-limit helper to $dst"
        sudo install -o root -g root -m 0755 "$src" "$dst"
    fi
    want1="$USER ALL=(root) NOPASSWD: $dst [4-9][0-9]"
    want2="$USER ALL=(root) NOPASSWD: $dst 100"
    if [ -f "$rules" ] && sudo grep -qxF "$want1" "$rules" 2>/dev/null && sudo grep -qxF "$want2" "$rules" 2>/dev/null; then
        log "charge-limit sudoers already in place"
    else
        log "granting $USER passwordless $dst (validated 40-100 only)"
        tmp="$(mktemp)"
        printf '%s\n%s\n' "$want1" "$want2" > "$tmp"
        sudo visudo -c -f "$tmp" >/dev/null
        sudo install -o root -g root -m 0440 "$tmp" "$rules"
        rm -f "$tmp"
    fi
}

ensure_system_services() {
    local svc usvc
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        log "would run: enable core system services when present (NetworkManager, bluetooth, upower, power-profiles-daemon)"
        log "would run: enable user audio session targets when possible (pipewire, wireplumber, pipewire-pulse)"
        return 0
    fi
    if ! command -v systemctl >/dev/null 2>&1 || [ ! -d /run/systemd/system ]; then
        warn "no systemd — skipping service enablement"
        return 0
    fi
    require_tty
    for svc in NetworkManager.service bluetooth.service upower.service power-profiles-daemon.service; do
        if systemctl cat "$svc" >/dev/null 2>&1; then
            if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
                log "service enabled: $svc"
            else
                log "enabling $svc"
                sudo systemctl enable "$svc" >/dev/null 2>&1 || warn "could not enable $svc"
                sudo systemctl start "$svc" >/dev/null 2>&1 || true
            fi
        else
            info "service not present (skipping): $svc"
        fi
    done
    if systemctl --user show-environment >/dev/null 2>&1; then
        for usvc in pipewire.socket pipewire-pulse.socket wireplumber.service; do
            if systemctl --user cat "$usvc" >/dev/null 2>&1; then
                if systemctl --user is-enabled --quiet "$usvc" 2>/dev/null; then
                    log "user service enabled: $usvc"
                else
                    systemctl --user enable "$usvc" >/dev/null 2>&1 || true
                    systemctl --user start "$usvc" >/dev/null 2>&1 || true
                fi
            fi
        done
    else
        info "no user systemd session bus — skipping user audio service enablement (will apply on login)"
    fi
}

provision_desktop_group() {
    echo
    phase "provision: desktop"
    ensure_copr "$COPR_HYPRLAND"
    dnf_install "${DESKTOP_PKGS[@]}"
    ensure_apple_emoji_font
    if command -v grimblast >/dev/null 2>&1; then
        log "found grimblast"
    elif dnf list --available grimblast 2>/dev/null | grep -q "^grimblast"; then
        dnf_install grimblast
    else
        warn "grimblast is in no enabled repo — installing the upstream script to /usr/local/bin"
        github_raw_install "https://raw.githubusercontent.com/hyprwm/contrib/main/grimblast/grimblast" "/usr/local/bin/grimblast"
        [ "${DRY_RUN:-0}" -eq 1 ] || grimblast check
    fi
    ensure_pam_keyring
    ensure_charge_helper
    ensure_system_services
}

provision_session_group() {
    echo
    phase "provision: session"
    ensure_copr "$COPR_HYPRLAND"
    dnf_install "${SESSION_PKGS[@]}"
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        log "would run: sudo systemctl set-default graphical.target (if not already)"
        log "would run: sudo systemctl enable sddm (if not already)"
        log "would run: uwsm check may-start; python3 -c 'import xdg'"
    elif ! command -v systemctl >/dev/null 2>&1 || [ ! -d /run/systemd/system ]; then
        warn "no systemd — skipping target/DM enablement (container or non-systemd host?)"
    else
        require_tty
        if [ "$(systemctl get-default)" != "graphical.target" ]; then
            log "setting default target to graphical.target (Fedora Server boots multi-user)"
            sudo systemctl set-default graphical.target
        else
            log "default target is already graphical.target"
        fi
        if systemctl is-enabled --quiet sddm 2>/dev/null; then
            log "sddm already enabled"
        else
            log "enabling sddm"
            sudo systemctl enable sddm
        fi
        if compgen -G "/usr/share/wayland-sessions/*.desktop" >/dev/null; then
            log "wayland session file(s) present"
        else
            warn "no .desktop in /usr/share/wayland-sessions — no session to pick at login"
        fi
        if command -v uwsm >/dev/null 2>&1; then
            if uwsm check may-start; then
                log "uwsm check may-start: OK"
            elif [ -n "${WAYLAND_DISPLAY:-}" ] || [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
                log "uwsm check may-start refuses inside a live session (expected — it gates fresh logins)"
            else
                warn "uwsm check may-start failed — check python3-pyxdg and seat state, see README"
            fi
        fi
        if python3 -c 'import xdg' 2>/dev/null; then
            log "python3 xdg module: OK"
        else
            warn "python3 -c 'import xdg' failed — uwsm sessions need python3-pyxdg"
        fi
        ensure_pam_keyring
    fi
}

provision_shell_group() {
    local p
    echo
    phase "provision: shell"
    dnf_install "${SHELL_PKGS[@]}"
    if command -v starship >/dev/null 2>&1; then
        log "found starship"
    elif dnf list --available starship 2>/dev/null | grep -q "^starship"; then
        dnf_install starship
    else
        warn "starship is in no enabled repo — using the upstream installer to /usr/local/bin"
        if [ "${DRY_RUN:-0}" -eq 1 ]; then
            log "would run: curl -sS https://starship.rs/install.sh | sudo sh -s -- --yes --bin-dir /usr/local/bin"
        else
            require_tty
            curl -sS https://starship.rs/install.sh | sudo sh -s -- --yes --bin-dir /usr/local/bin
        fi
    fi
    if [ -d "$HOME/.oh-my-zsh" ]; then
        log "found oh-my-zsh"
    elif [ "${DRY_RUN:-0}" -eq 1 ]; then
        log "would run: oh-my-zsh unattended install (keeps existing .zshrc)"
    else
        require_tty
        log "installing oh-my-zsh (unattended, keeps .zshrc)"
        KEEP_ZSHRC=yes RUNZSH=no CHSH=no \
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    for p in zsh-autosuggestions zsh-syntax-highlighting; do
        if [ -d "$ZSH_CUSTOM/plugins/$p" ]; then
            log "found oh-my-zsh plugin $p"
        elif [ "${DRY_RUN:-0}" -eq 1 ]; then
            log "would run: git clone zsh-users/$p -> $ZSH_CUSTOM/plugins/$p"
        else
            log "cloning oh-my-zsh plugin $p"
            git clone --depth 1 "https://github.com/zsh-users/$p.git" "$ZSH_CUSTOM/plugins/$p"
        fi
    done
    if [ -s "$HOME/.nvm/nvm.sh" ]; then
        log "found nvm"
    elif [ "${DRY_RUN:-0}" -eq 1 ]; then
        log "would run: git clone nvm-sh/nvm -> ~/.nvm (latest tag)"
    else
        log "installing nvm"
        git clone https://github.com/nvm-sh/nvm.git "$HOME/.nvm"
        (cd "$HOME/.nvm" && git checkout "$(git describe --abbrev=0 --tags)") \
            || warn "nvm tag checkout failed — nvm may be on an unexpected ref"
    fi
    if ! command -v zsh >/dev/null 2>&1; then
        warn "zsh not installed — skipping the login-shell change"
    elif [ "${SHELL:-}" = "$(command -v zsh)" ]; then
        log "login shell is already zsh"
    elif [ "${DRY_RUN:-0}" -eq 1 ]; then
        log "would run: chsh -s $(command -v zsh) (asks first)"
    else
        require_tty
        if [ "${ASSUME_YES:-0}" -eq 1 ] || confirm "Make zsh your login shell?"; then
            chsh -s "$(command -v zsh)" && log "login shell is now zsh (takes effect on next login)" || warn "could not change login shell automatically (run: chsh -s \"$(command -v zsh)\")"
        else
            warn "left the login shell as ${SHELL:-unknown}"
        fi
    fi
}

provision_nvidia_group() {
    echo
    phase "provision: nvidia"
    dnf_install pciutils
    if ! lspci 2>/dev/null | grep -qi "nvidia"; then
        warn "no NVIDIA GPU in lspci — skipping the driver, installing nothing"
        return 0
    fi
    ensure_rpmfusion
    dnf_install "${NVIDIA_PKGS[@]}"
    if command -v envycontrol >/dev/null 2>&1; then
        log "found envycontrol"
    else
        ensure_copr "$COPR_ENVY"
        if dnf list --available python3-envycontrol 2>/dev/null | grep -q "^python3-envycontrol"; then
            dnf_install python3-envycontrol
        elif dnf list --available envycontrol 2>/dev/null | grep -q "^envycontrol"; then
            dnf_install envycontrol
        else
            warn "envycontrol is in no enabled repo — skipping (optional GPU switcher; install python3-envycontrol from the sunwire/envycontrol COPR by hand)"
        fi
    fi
    if [ "${DRY_RUN:-0}" -eq 0 ] && command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -qi enabled; then
        warn "Secure Boot is on: akmods needs its key enrolled or the driver will not load."
        warn "Once: sudo mokutil --import /etc/pki/akmods/certs/public_key.der, then reboot and enroll in the MOK screen."
    fi
}

provision_dev_group() {
    echo
    phase "provision: dev"
    ensure_docker_repo
    dnf_install "${DEV_PKGS[@]}"
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        log "would run: sudo systemctl enable --now docker.service; sudo usermod -aG docker $USER"
    else
        sudo systemctl enable --now docker.service
        if id -nG "$USER" | grep -qw docker; then
            log "$USER is in the docker group"
        else
            sudo usermod -aG docker "$USER"
            warn "added $USER to the docker group — log out/in before docker works without sudo"
        fi
    fi
}

provision_link_step() {
    echo
    if [ "${NO_LINK:-0}" -eq 1 ]; then
        log "skipping the link step (--no-link)"
    elif [ "${DRY_RUN:-0}" -eq 1 ]; then
        bash "$REPO_DIR/install.sh" --dry-run
    elif [ "${ASSUME_YES:-0}" -eq 1 ]; then
        bash "$REPO_DIR/install.sh" --yes
    else
        bash "$REPO_DIR/install.sh"
    fi
}

provision_login_theme() {
    [ "${WANT_SESSION:-0}" -eq 1 ] || return 0
    echo
    phase "provision: login theme"
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        log "would run: scripts/sync-login-wallpaper.sh (skipped with no live session)"
        if [ "${ASSUME_YES:-0}" -eq 1 ]; then
            log "would run: scripts/install-sddm.sh --yes"
        else
            log "would run: scripts/install-sddm.sh (asks first)"
        fi
        return 0
    fi
    if compgen -G "$HOME/.local/state/quickshell/by-shell/*/theme-state.json" >/dev/null; then
        bash "$REPO_DIR/scripts/sync-login-wallpaper.sh" || warn "wallpaper sync failed — the theme keeps its bundled photo"
    else
        log "no live session — the theme keeps its bundled photo (run scripts/sync-login-wallpaper.sh after first login)"
    fi
    if [ "${ASSUME_YES:-0}" -eq 1 ]; then
        bash "$REPO_DIR/scripts/install-sddm.sh" --yes || warn "login theme failed — run scripts/install-sddm.sh by hand"
    elif [ -t 0 ]; then
        bash "$REPO_DIR/scripts/install-sddm.sh" || warn "login theme failed — run scripts/install-sddm.sh by hand"
    else
        warn "no terminal to confirm on — skipping the login theme (run scripts/install-sddm.sh once interactively)"
    fi
}
