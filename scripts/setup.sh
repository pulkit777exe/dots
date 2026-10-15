#!/usr/bin/env bash
# setup.sh — provision a Fedora machine for this dots repo, then link it.
#
# Installs dnf packages per group, fills the gaps dnf cannot cover
# (oh-my-zsh + plugins, nvm, starship, grimblast, envycontrol), then runs
# install.sh. Idempotent: anything already present is skipped.
#
# Usage: ./scripts/setup.sh [--dry-run] [--yes] [--all] [--desktop]
#                            [--shell] [--session] [--nvidia] [--dev] [--no-link] [--list] [--help]
#
# With no group flag it installs desktop + shell + session. --nvidia reboots nothing
# itself but the driver needs one; it says so at the end.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=0
ASSUME_YES=0
WANT_DESKTOP=0
WANT_SHELL=0
WANT_SESSION=0
WANT_NVIDIA=0
WANT_DEV=0
GROUPS_GIVEN=0
NO_LINK=0

# shellcheck disable=SC1091
. "$REPO_DIR/scripts/lib.sh"

# log/warn/err/die/run/confirm come from scripts/lib.sh (sourced above).

usage() {
    cat <<'USAGE'
usage: scripts/setup.sh [--dry-run] [--yes] [--all] [--desktop] [--shell]
                        [--session] [--nvidia] [--dev] [--list] [--help]

  --dry-run   print the plan without touching anything
  --yes       pass -y to dnf / copr and skip confirmations
  --all       install every group below
  --desktop   compositor, shell runtime, screenshot + media tools
  --shell     zsh, prompt, jumpers, oh-my-zsh, plugins, nvm
  --session   login session: sddm + sequoia theme, uwsm, graphical target, session checks
  --nvidia    RPM Fusion + akmod driver, CUDA, VA-API, envycontrol
  --dev       docker, kubectl, neovim, qmllint, lint tooling
  --no-link   packages only; skip the install.sh link step at the end
  --list      show the package groups and exit
  --help      show this message

With no group flag: --desktop --shell --session.
USAGE
}

DESKTOP_PKGS=(
    hyprland hyprpaper hyprlock hypridle hyprsunset quickshell
    kitty Thunar gvfs
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    grim slurp wl-clipboard cliphist
    polkit upower bluez NetworkManager wireplumber pipewire
    hyprpolkitagent
    gnome-keyring seahorse
    polkit upower bluez NetworkManager wireplumber pipewire
    brightnessctl playerctl ddcutil pciutils
    lua power-profiles-daemon unzip p7zip
    python3 python3-pillow fontconfig libnotify
    git curl flatpak
)
# NOTE: upower stays — Battery.qml binds Quickshell.Services.UPower, which
# talks to the UPower system daemon over D-Bus. jq is gone (nothing used
# it). libnotify stays: the hypr config-error path notifies via
# notify-send when present. unrar is deliberately absent (RPM Fusion
# nonfree); extract() uses 7z for .rar instead.
SHELL_PKGS=(zsh zoxide eza bat btop fastfetch)
# Login session. sddm + python3-pyxdg are in the official repos; uwsm and
# hyprland-guiutils ride on the hyprland COPR enabled by the desktop group,
# so --session must run after --desktop (it does: blocks run in file order).
SESSION_PKGS=(sddm uwsm python3-pyxdg hyprland-guiutils)
NVIDIA_PKGS=(akmod-nvidia xorg-x11-drv-nvidia-cuda libva-nvidia-driver mokutil)
DEV_PKGS=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin
    docker-compose-plugin kubectl neovim python3-pip
    qt6-qtdeclarative-devel binutils)

COPR_HYPRLAND="nett00n/hyprland"
COPR_ENVY="sunwire/envycontrol"

list_groups() {
    echo "desktop: ${DESKTOP_PKGS[*]} (+ grimblast; third-party apps are ./dots apps)"
    echo "shell:   ${SHELL_PKGS[*]} (+ starship, oh-my-zsh, plugins, nvm)"
    echo "session: ${SESSION_PKGS[*]} (+ sequoia login theme, graphical target, sddm enable, session checks)"
    echo "nvidia:  ${NVIDIA_PKGS[*]} (+ envycontrol)"
    echo "dev:     ${DEV_PKGS[*]}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        -y|--yes)  ASSUME_YES=1 ;;
        --all)     WANT_DESKTOP=1; WANT_SHELL=1; WANT_SESSION=1; WANT_NVIDIA=1; WANT_DEV=1; GROUPS_GIVEN=1 ;;
        --desktop) WANT_DESKTOP=1; GROUPS_GIVEN=1 ;;
        --shell)   WANT_SHELL=1; GROUPS_GIVEN=1 ;;
        --session) WANT_SESSION=1; GROUPS_GIVEN=1 ;;
        --nvidia)  WANT_NVIDIA=1; GROUPS_GIVEN=1 ;;
        --dev)     WANT_DEV=1; GROUPS_GIVEN=1 ;;
        --no-link) NO_LINK=1 ;;
        --list)    list_groups; exit 0 ;;
        -h|--help) usage; exit 0 ;;
        *)         err "unknown argument: $1"; usage >&2; exit 2 ;;
    esac
    shift
done

[ "$GROUPS_GIVEN" -eq 0 ] && { WANT_DESKTOP=1; WANT_SHELL=1; WANT_SESSION=1; }

# --yes was silently always-on: ${ASSUME_YES:+-y} expands whenever the
# variable is set, even to 0 (it is initialised to 0 above). Build the flag
# once, honestly.
DNF_YES=()
[ "$ASSUME_YES" -eq 1 ] && DNF_YES=(-y)

[ "$(id -u)" -eq 0 ] && die "Refusing to run as root. Run as your normal user; sudo is used per-command."
[ -f /etc/fedora-release ] || die "This provisions Fedora (dnf). Detected: $(uname -s)."

need_tty() {
    if [ "$ASSUME_YES" -eq 0 ] && [ ! -t 0 ]; then
        die "No terminal to confirm on. Re-run with --yes."
    fi
}

command -v dnf >/dev/null 2>&1 || die "dnf not found."
command -v sudo >/dev/null 2>&1 || die "sudo not found."
if ! command -v curl >/dev/null 2>&1; then
    if [ "$DRY_RUN" -eq 1 ]; then
        log "would run: sudo dnf install curl"
    else
        need_tty
        sudo dnf install "${DNF_YES[@]}" curl
    fi
fi

pkg_installed() { rpm -q "$1" >/dev/null 2>&1; }

dnf_install() {
    local missing=()
    local p
    for p in "$@"; do
        pkg_installed "$p" || missing+=("$p")
    done
    [ "${#missing[@]}" -eq 0 ] && return 0
    if [ "$DRY_RUN" -eq 1 ]; then
        log "would run: sudo dnf install ${missing[*]}"
        return 0
    fi
    need_tty
    log "installing: ${missing[*]}"
    sudo dnf install "${DNF_YES[@]}" "${missing[@]}"
}

ensure_copr() {
    if dnf copr list 2>/dev/null | grep -q "$1"; then
        return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        log "would run: sudo dnf copr enable $1"
        return 0
    fi
    need_tty
    log "enabling copr $1"
    sudo dnf copr enable "${DNF_YES[@]}" "$1"
}

ensure_rpmfusion() {
    if dnf repolist --enabled 2>/dev/null | grep -q "rpmfusion-nonfree"; then
        return 0
    fi
    local ver
    ver="$(rpm -E %fedora)"
    if [ "$DRY_RUN" -eq 1 ]; then
        log "would run: sudo dnf install rpmfusion-free-release + rpmfusion-nonfree-release ($ver)"
        return 0
    fi
    need_tty
    log "enabling RPM Fusion free + nonfree"
    sudo dnf install "${DNF_YES[@]}" \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$ver.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$ver.noarch.rpm"
}

github_raw() {
    # Trust posture, stated plainly: this fetches unpinned upstream code
    # (floating branch) and installs it as root. The only post-condition is
    # the caller's own check afterwards (grimblast check). Prefer a distro
    # package whenever one exists — see the grimblast/starship branches below.
    if [ "$DRY_RUN" -eq 1 ]; then
        log "would run: curl -fsSL $1 -> $2 (chmod +x)"
    else
        log "fetching $(basename "$2") from upstream"
        sudo curl -fsSL "$1" -o "$2"
        sudo chmod +x "$2"
    fi
}

ensure_docker_repo() {
    # docker-ce is not in Fedora's repos; without this --dev fails on a
    # clean machine asking dnf for packages no enabled repo carries.
    if dnf repolist --enabled 2>/dev/null | grep -qi "docker-ce"; then
        return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        log "would run: add Docker CE repo from download.docker.com"
        return 0
    fi
    need_tty
    log "adding Docker CE repo"
    if dnf config-manager --help 2>/dev/null | grep -q "from-repofile"; then
        sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
    else
        sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    fi
}

ensure_pam_keyring() {
    # SDDM unlocks the Login keyring at graphical login via
    # pam_gnome_keyring; without these lines Brave prompts for the keyring
    # password on every boot. Appended late in each section to match the
    # distro layout (auth after the password substack, session at the end).
    # A backup is kept next to the file; the lines are `optional`, so a
    # bad edit can never lock anyone out.
    local pam=/etc/pam.d/sddm
    if [ ! -f "$pam" ]; then
        warn "no $pam — skipping keyring PAM setup"
        return 0
    fi
    if grep -q "pam_gnome_keyring\.so" "$pam"; then
        log "sddm PAM already unlocks the keyring"
        return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        log "would run: add pam_gnome_keyring auth+session lines to $pam (with backup)"
        return 0
    fi
    need_tty
    log "enabling keyring unlock in $pam"
    sudo cp "$pam" "$pam.pre-dots-$(date +%Y%m%d-%H%M%S)"
    echo "-auth      optional      pam_gnome_keyring.so" | sudo tee -a "$pam" >/dev/null
    echo "-session   optional      pam_gnome_keyring.so auto_start" | sudo tee -a "$pam" >/dev/null
}

if [ "$WANT_DESKTOP" -eq 1 ]; then
    echo
    log "group: desktop"
    ensure_copr "$COPR_HYPRLAND"
    dnf_install "${DESKTOP_PKGS[@]}"
    if command -v grimblast >/dev/null 2>&1; then
        log "found grimblast"
    elif dnf list --available grimblast 2>/dev/null | grep -q "^grimblast"; then
        dnf_install grimblast
    else
        warn "grimblast is in no enabled repo — installing the upstream script to /usr/local/bin"
        github_raw "https://raw.githubusercontent.com/hyprwm/contrib/main/grimblast/grimblast" \
            "/usr/local/bin/grimblast"
        [ "$DRY_RUN" -eq 1 ] || grimblast check
    fi
    ensure_pam_keyring
fi

if [ "$WANT_SESSION" -eq 1 ]; then
    echo
    log "group: session"
    dnf_install "${SESSION_PKGS[@]}"
    if [ "$DRY_RUN" -eq 1 ]; then
        log "would run: sudo systemctl set-default graphical.target (if not already)"
        log "would run: sudo systemctl enable sddm (if not already)"
        log "would run: uwsm check may-start; python3 -c 'import xdg'"
    elif ! command -v systemctl >/dev/null 2>&1 || [ ! -d /run/systemd/system ]; then
        warn "no systemd — skipping target/DM enablement (container or non-systemd host?)"
    else
        need_tty
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
        if ls /usr/share/wayland-sessions/*.desktop >/dev/null 2>&1; then
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
    fi
fi

if [ "$WANT_SHELL" -eq 1 ]; then
    echo
    log "group: shell"
    dnf_install "${SHELL_PKGS[@]}"
    if command -v starship >/dev/null 2>&1; then
        log "found starship"
    elif dnf list --available starship 2>/dev/null | grep -q "^starship"; then
        dnf_install starship
    else
        warn "starship is in no enabled repo — using the upstream installer to /usr/local/bin"
        # Unpinned upstream code piped to root sh; no versioned URL exists
        # for this installer. Documented, not fixed: prefer distro package.
        if [ "$DRY_RUN" -eq 1 ]; then
            log "would run: curl -sS https://starship.rs/install.sh | sudo sh -s -- --yes --bin-dir /usr/local/bin"
        else
            need_tty
            curl -sS https://starship.rs/install.sh | sudo sh -s -- --yes --bin-dir /usr/local/bin
        fi
    fi
    if [ -d "$HOME/.oh-my-zsh" ]; then
        log "found oh-my-zsh"
    elif [ "$DRY_RUN" -eq 1 ]; then
        log "would run: oh-my-zsh unattended install (keeps existing .zshrc)"
    else
        need_tty
        log "installing oh-my-zsh (unattended, keeps .zshrc)"
        # Unpinned master installer + master clone. Mitigation: KEEP_ZSHRC
        # preserves your config, RUNZSH/CHSH disable surprises; review the
        # login-shell step (S3) separately — this installer is told not to.
        KEEP_ZSHRC=yes RUNZSH=no CHSH=no \
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    for p in zsh-autosuggestions zsh-syntax-highlighting; do
        if [ -d "$ZSH_CUSTOM/plugins/$p" ]; then
            log "found oh-my-zsh plugin $p"
        elif [ "$DRY_RUN" -eq 1 ]; then
            log "would run: git clone zsh-users/$p -> $ZSH_CUSTOM/plugins/$p"
        else
            log "cloning oh-my-zsh plugin $p"
            git clone --depth 1 "https://github.com/zsh-users/$p.git" "$ZSH_CUSTOM/plugins/$p"
        fi
    done
    if [ -s "$HOME/.nvm/nvm.sh" ]; then
        log "found nvm"
    elif [ "$DRY_RUN" -eq 1 ]; then
        log "would run: git clone nvm-sh/nvm -> ~/.nvm (latest tag)"
    else
        log "installing nvm"
        git clone https://github.com/nvm-sh/nvm.git "$HOME/.nvm"
        (cd "$HOME/.nvm" && git checkout "$(git describe --abbrev=0 --tags)")
    fi
    if ! command -v zsh >/dev/null 2>&1; then
        warn "zsh not installed — skipping the login-shell change"
    elif [ "${SHELL:-}" = "$(command -v zsh)" ]; then
        log "login shell is already zsh"
    elif [ "$DRY_RUN" -eq 1 ]; then
        log "would run: chsh -s $(command -v zsh) (asks first)"
    else
        need_tty
        if confirm "Make zsh your login shell?"; then
            chsh -s "$(command -v zsh)" && log "login shell is now zsh (takes effect on next login)"
        else
            warn "left the login shell as ${SHELL:-unknown}"
        fi
    fi
fi

if [ "$WANT_NVIDIA" -eq 1 ]; then
    echo
    log "group: nvidia"
    dnf_install pciutils
    if ! lspci 2>/dev/null | grep -qi "nvidia"; then
        warn "no NVIDIA GPU in lspci — skipping the driver, installing nothing"
    else
        ensure_rpmfusion
        dnf_install "${NVIDIA_PKGS[@]}"
        if command -v envycontrol >/dev/null 2>&1; then
            log "found envycontrol"
        else
            ensure_copr "$COPR_ENVY"
            if dnf list --available envycontrol 2>/dev/null | grep -q "^envycontrol"; then
                dnf_install envycontrol
            else
                warn "envycontrol is in no enabled repo — pip-installing to /usr/local/bin"
                dnf_install python3-pip
                if [ "$DRY_RUN" -eq 1 ]; then
                    log "would run: sudo python3 -m pip install envycontrol"
                else
                    need_tty
                    sudo python3 -m pip install envycontrol \
                        || warn "envycontrol pip install failed — optional GPU switcher, skipping (see github.com/bayasdev/envycontrol)"
                fi
            fi
        fi
        if [ "$DRY_RUN" -eq 0 ] && command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -qi enabled; then
            warn "Secure Boot is on: akmods needs its key enrolled or the driver will not load."
            warn "Once: sudo mokutil --import /etc/pki/akmods/certs/public_key.der, then reboot and enroll in the MOK screen."
        fi
    fi
fi

if [ "$WANT_DEV" -eq 1 ]; then
    echo
    log "group: dev"
    ensure_docker_repo
    dnf_install "${DEV_PKGS[@]}"
    if [ "$DRY_RUN" -eq 1 ]; then
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
fi

echo
if [ "$NO_LINK" -eq 1 ]; then
    log "skipping the link step (--no-link)"
elif [ "$DRY_RUN" -eq 1 ]; then
    bash "$REPO_DIR/install.sh" --dry-run
elif [ "$ASSUME_YES" -eq 1 ]; then
    bash "$REPO_DIR/install.sh" --yes
else
    bash "$REPO_DIR/install.sh"
fi

# The login theme rides the session group: it needs sddm from SESSION_PKGS,
# and installs from the repo copy, so it works with --no-link too (the link
# step above is what makes the shared wallpaper live for hyprlock at
# ~/.config/sddm/...). install.sh stays sudo-free configs-only; the sudo
# steps live here. Third-party apps are deliberately NOT here — they are
# ./dots apps (./install-software) in the front end.

if [ "$WANT_SESSION" -eq 1 ]; then
    echo
    log "login theme (sequoia)"
    if [ "$DRY_RUN" -eq 1 ]; then
        log "would run: scripts/sync-login-wallpaper.sh (skipped with no live session)"
        if [ "$ASSUME_YES" -eq 1 ]; then
            log "would run: scripts/install-sddm.sh --yes"
        else
            log "would run: scripts/install-sddm.sh (asks first)"
        fi
    else
        if ls "$HOME"/.local/state/quickshell/by-shell/*/theme-state.json >/dev/null 2>&1; then
            bash "$REPO_DIR/scripts/sync-login-wallpaper.sh" || warn "wallpaper sync failed — the theme keeps its bundled photo"
        else
            log "no live session — the theme keeps its bundled photo (run scripts/sync-login-wallpaper.sh after first login)"
        fi
        if [ "$ASSUME_YES" -eq 1 ]; then
            bash "$REPO_DIR/scripts/install-sddm.sh" --yes || warn "login theme failed — run scripts/install-sddm.sh by hand"
        elif [ -t 0 ]; then
            bash "$REPO_DIR/scripts/install-sddm.sh" || warn "login theme failed — run scripts/install-sddm.sh by hand"
        else
            warn "no terminal to confirm on — skipping the login theme (run scripts/install-sddm.sh once interactively)"
        fi
    fi
fi

echo
log "setup done — verify with ./dots check and ./scripts/install-sddm.sh --check"

if [ "$WANT_NVIDIA" -eq 1 ] && [ "$DRY_RUN" -eq 0 ] \
    && lspci 2>/dev/null | grep -qi "nvidia"; then
    echo
    warn "NVIDIA driver installed or updated — reboot to load it."
    warn "On first driver install the akmods build can take a few minutes after boot."
fi
