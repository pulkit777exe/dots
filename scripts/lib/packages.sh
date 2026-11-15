#!/usr/bin/env bash
# Data-driven package groups and repository/capability metadata for Fedora provisioning.

# shellcheck shell=bash

# Package groups
DESKTOP_PKGS=(
    hyprland hyprpaper hyprlock hypridle hyprsunset quickshell
    kitty Thunar gvfs
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    grim slurp wl-clipboard cliphist
    polkit upower bluez NetworkManager wireplumber pipewire
    hyprpolkitagent
    gnome-keyring seahorse
    brightnessctl playerctl ddcutil pciutils
    lua power-profiles-daemon unzip p7zip
    python3 python3-pillow python3-gobject python3-dbus fontconfig libnotify
    git curl flatpak
)

SHELL_PKGS=(zsh zoxide eza bat btop fastfetch)

SESSION_PKGS=(sddm uwsm python3-pyxdg hyprland-guiutils)

NVIDIA_PKGS=(akmod-nvidia xorg-x11-drv-nvidia-cuda libva-nvidia-driver mokutil)

DEV_PKGS=(
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin
    docker-compose-plugin kubectl neovim python3-pip
    qt6-qtdeclarative-devel binutils
)

# External repos/capabilities
COPR_HYPRLAND="nett00n/hyprland"
COPR_ENVY="sunwire/envycontrol"

APPLE_EMOJI_PKG="fonts-apple-color-emoji"
APPLE_EMOJI_RPM_URL="https://github.com/samuelngs/apple-emoji-ttf/releases/latest/download/fonts-apple-color-emoji.rpm"

list_package_groups() {
    echo "desktop: ${DESKTOP_PKGS[*]} (+ grimblast, latest Apple Color Emoji RPM; third-party apps are ./dots apps)"
    echo "shell:   ${SHELL_PKGS[*]} (+ starship, oh-my-zsh, plugins, nvm)"
    echo "session: ${SESSION_PKGS[*]} (+ sequoia login theme, graphical target, sddm enable, session checks)"
    echo "nvidia:  ${NVIDIA_PKGS[*]} (+ envycontrol)"
    echo "dev:     ${DEV_PKGS[*]}"
}

pkg_installed() { rpm -q "$1" >/dev/null 2>&1; }

dnf_install() {
    local missing=() p
    for p in "$@"; do
        pkg_installed "$p" || missing+=("$p")
    done
    [ "${#missing[@]}" -eq 0 ] && return 0
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        log "would run: sudo dnf install ${missing[*]}"
        return 0
    fi
    require_tty
    log "installing: ${missing[*]}"
    sudo dnf install "${DNF_YES[@]}" "${missing[@]}"
}

ensure_copr() {
    local copr="$1"
    if dnf copr list 2>/dev/null | grep -q "$copr"; then
        return 0
    fi
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        log "would run: sudo dnf copr enable $copr"
        return 0
    fi
    require_tty
    log "enabling copr $copr"
    sudo dnf copr enable "${DNF_YES[@]}" "$copr"
}

ensure_rpmfusion() {
    if dnf repolist --enabled 2>/dev/null | grep -q "rpmfusion-nonfree"; then
        return 0
    fi
    local ver
    ver="$(rpm -E %fedora)"
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        log "would run: sudo dnf install rpmfusion-free-release + rpmfusion-nonfree-release ($ver)"
        return 0
    fi
    require_tty
    log "enabling RPM Fusion free + nonfree"
    sudo dnf install "${DNF_YES[@]}" \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$ver.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$ver.noarch.rpm"
}

ensure_docker_repo() {
    if dnf repolist --enabled 2>/dev/null | grep -qi "docker-ce"; then
        return 0
    fi
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        log "would run: add Docker CE repo from download.docker.com"
        return 0
    fi
    require_tty
    log "adding Docker CE repo"
    if dnf config-manager --help 2>/dev/null | grep -q "from-repofile"; then
        sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
    else
        sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    fi
}

github_raw_install() {
    local url="$1" dst="$2"
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        log "would run: curl -fsSL $url -> $dst (chmod +x)"
    else
        log "fetching $(basename "$dst") from upstream"
        sudo curl -fsSL "$url" -o "$dst"
        sudo chmod +x "$dst"
    fi
}
