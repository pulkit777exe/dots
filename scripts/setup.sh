#!/usr/bin/env bash
# setup.sh — provision a Fedora machine for this dots repo, then link it.
#
# Installs dnf packages per group, fills the gaps dnf cannot cover
# (oh-my-zsh + plugins, nvm, starship, grimblast, envycontrol), then runs
# install.sh. Idempotent: anything already present is skipped.
#
# Usage: ./scripts/setup.sh [--dry-run] [--yes] [--all] [--desktop]
#                            [--shell] [--nvidia] [--dev] [--list] [--help]
#
# With no group flag it installs desktop + shell. --nvidia reboots nothing
# itself but the driver needs one; it says so at the end.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=0
ASSUME_YES=0
WANT_DESKTOP=0
WANT_SHELL=0
WANT_NVIDIA=0
WANT_DEV=0
GROUPS_GIVEN=0

log()  { printf '\033[1;32m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1" >&2; }
err()  { printf '\033[1;31mxx\033[0m %s\n' "$1" >&2; }
die()  { err "$1"; exit 1; }

usage() {
    cat <<'USAGE'
usage: scripts/setup.sh [--dry-run] [--yes] [--all] [--desktop] [--shell]
                        [--nvidia] [--dev] [--list] [--help]

  --dry-run   print the plan without touching anything
  --yes       pass -y to dnf / copr and skip confirmations
  --all       install every group below
  --desktop   compositor, shell runtime, apps, screenshot + media tools
  --shell     zsh, prompt, jumpers, oh-my-zsh, plugins, nvm
  --nvidia    RPM Fusion + akmod driver, CUDA, VA-API, envycontrol
  --dev       docker, kubectl, neovim, qmllint, lint tooling
  --list      show the package groups and exit
  --help      show this message

With no group flag: --desktop --shell.
USAGE
}

DESKTOP_PKGS=(
    hyprland hyprpaper hyprlock hypridle hyprsunset quickshell
    kitty Thunar gvfs
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    grim slurp wl-clipboard cliphist
    polkit upower bluez NetworkManager wireplumber pipewire
    brightnessctl playerctl ddcutil pciutils
    python3 python3-pillow fontconfig jq libnotify
    git curl
)
SHELL_PKGS=(zsh zoxide eza bat btop fastfetch)
NVIDIA_PKGS=(akmod-nvidia xorg-x11-drv-nvidia-cuda libva-nvidia-driver mokutil)
DEV_PKGS=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin
    docker-compose-plugin kubectl neovim python3-pip
    qt6-qtdeclarative-devel binutils)

COPR_HYPRLAND="nett00n/hyprland"
COPR_ENVY="sunwire/envycontrol"

list_groups() {
    echo "desktop: ${DESKTOP_PKGS[*]} (+ grimblast, see below)"
    echo "shell:   ${SHELL_PKGS[*]} (+ starship, oh-my-zsh, plugins, nvm)"
    echo "nvidia:  ${NVIDIA_PKGS[*]} (+ envycontrol)"
    echo "dev:     ${DEV_PKGS[*]}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        -y|--yes)  ASSUME_YES=1 ;;
        --all)     WANT_DESKTOP=1; WANT_SHELL=1; WANT_NVIDIA=1; WANT_DEV=1; GROUPS_GIVEN=1 ;;
        --desktop) WANT_DESKTOP=1; GROUPS_GIVEN=1 ;;
        --shell)   WANT_SHELL=1; GROUPS_GIVEN=1 ;;
        --nvidia)  WANT_NVIDIA=1; GROUPS_GIVEN=1 ;;
        --dev)     WANT_DEV=1; GROUPS_GIVEN=1 ;;
        --list)    list_groups; exit 0 ;;
        -h|--help) usage; exit 0 ;;
        *)         err "unknown argument: $1"; usage >&2; exit 2 ;;
    esac
    shift
done

[ "$GROUPS_GIVEN" -eq 0 ] && { WANT_DESKTOP=1; WANT_SHELL=1; }

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
        sudo dnf install ${ASSUME_YES:+-y} curl
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
    sudo dnf install ${ASSUME_YES:+-y} "${missing[@]}"
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
    sudo dnf copr enable ${ASSUME_YES:+-y} "$1"
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
    sudo dnf install ${ASSUME_YES:+-y} \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$ver.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$ver.noarch.rpm"
}

github_raw() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log "would run: curl -fsSL $1 -> $2 (chmod +x)"
    else
        log "fetching $(basename "$2") from upstream"
        sudo curl -fsSL "$1" -o "$2"
        sudo chmod +x "$2"
    fi
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
                    sudo python3 -m pip install envycontrol
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
log "linking dotfiles"
if [ "$DRY_RUN" -eq 1 ]; then
    bash "$REPO_DIR/install.sh" --dry-run
elif [ "$ASSUME_YES" -eq 1 ]; then
    bash "$REPO_DIR/install.sh" --yes
else
    bash "$REPO_DIR/install.sh"
fi

if [ "$WANT_NVIDIA" -eq 1 ] && [ "$DRY_RUN" -eq 0 ] \
    && lspci 2>/dev/null | grep -qi "nvidia"; then
    echo
    warn "NVIDIA driver installed or updated — reboot to load it."
    warn "On first driver install the akmods build can take a few minutes after boot."
fi
