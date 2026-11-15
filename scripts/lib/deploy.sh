#!/usr/bin/env bash
# Deploy/link managed config units and home files (idempotent, backup-only).

# shellcheck shell=bash

deploy_configs() {
    local repo_dir="${1:?repo_dir required}" config_dir="${2:?config_dir required}"
    local u
    phase "deploy: link configs"
    for u in "${DOTS_CONFIG_UNITS[@]}"; do
        backup_and_link "$repo_dir/$u" "$config_dir/$u" || true
    done
    echo
    log "linking home files"
    for pair in ${DOTS_HOME_FILES+"${DOTS_HOME_FILES[@]}"}; do
        backup_and_link "$repo_dir/${pair%%:*}" "$HOME/${pair##*:}" || true
    done
}
