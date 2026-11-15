#!/usr/bin/env bash
# Manifest: declarative lists of managed config units and file mappings.
# Sourced by install/deploy/check modules.

# shellcheck shell=bash

DOTS_CONFIG_UNITS=(colors hypr kitty quickshell sddm vlc Thunar)

# Repo-rel-source:home-rel-dest pairs for files linked into $HOME.
DOTS_HOME_FILES=(zsh/.zshrc:.zshrc)

dots_config_dir() { printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}"; }

dots_required_runtime_files() {
    local config_dir
    config_dir="$(dots_config_dir)"
    printf '%s\n' \
        "$config_dir/quickshell/shell.qml" \
        "$config_dir/quickshell/modules/Keybinds.qml" \
        "$config_dir/quickshell/modules/qmldir" \
        "$config_dir/hypr/hyprland.lua" \
        "$config_dir/colors/index.json" \
        "$config_dir/kitty/kitty.conf"
}

dots_generated_runtime_files() {
    local state_home config_dir
    state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
    config_dir="$(dots_config_dir)"
    printf '%s\n' \
        "$state_home/quickshell/hypr.lua" \
        "$config_dir/hypr/hypridle.conf" \
        "$config_dir/hypr/hyprlock.conf"
}
