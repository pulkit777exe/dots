#!/usr/bin/env bash
# Generate derived/runtime state and apply migrations.

# shellcheck shell=bash

ensure_runtime_dirs() {
    local config_dir state_home
    config_dir="$(dots_config_dir)"
    state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
    mkdir -p "$(dots_state_dir)" "$(dots_migration_dir)" "$(dots_log_dir)" \
        "$state_home/quickshell" "$config_dir/hypr" "$config_dir/colors" 2>/dev/null || true
}

apply_migrations_phase() {
    local repo_dir="${1:?repo_dir required}"
    if [ -x "$repo_dir/scripts/migrate.sh" ] || [ -f "$repo_dir/scripts/migrate.sh" ]; then
        bash "$repo_dir/scripts/migrate.sh" || warn "migrations reported an issue (continuing)"
    fi
}

generate_runtime_state() {
    local config_dir
    config_dir="$(dots_config_dir)"
    log "generating derived state (themes/colors, hypr overrides, idle/lock config)"
    if command -v python3 >/dev/null 2>&1; then
        run python3 "$config_dir/quickshell/scripts/list-themes.py" >/dev/null || warn "list-themes.py failed — run it by hand"
        run python3 "$config_dir/quickshell/scripts/publish-colors.py" || warn "publish-colors.py failed — run it by hand"
        run python3 "$config_dir/quickshell/scripts/generate-hypridle-conf.py" || warn "generate-hypridle-conf.py failed — run it by hand"
        run python3 "$config_dir/quickshell/scripts/generate-hypr-conf.py" || warn "generate-hypr-conf.py failed — run it by hand"
    else
        warn "python3 not found — generated runtime state was not refreshed"
    fi
    if command -v lua >/dev/null 2>&1; then
        run lua "$config_dir/hypr/hyprlock.lua" || warn "hyprlock.conf not generated — run it by hand"
    else
        warn "lua not found — hyprlock.conf not generated (sudo dnf install lua)"
    fi
}

verify_generated_runtime() {
    local state_home config_dir crit_fail=0
    state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
    config_dir="$(dots_config_dir)"
    if [ ! -s "$state_home/quickshell/hypr.lua" ]; then
        err "critical: missing generated $state_home/quickshell/hypr.lua"
        crit_fail=1
    else
        log "generated: ${state_home}/quickshell/hypr.lua"
    fi
    if [ ! -s "$config_dir/hypr/hypridle.conf" ]; then
        err "critical: missing generated $config_dir/hypr/hypridle.conf"
        crit_fail=1
    else
        log "generated: ${config_dir}/hypr/hypridle.conf"
    fi
    if [ ! -s "$config_dir/hypr/hyprlock.conf" ]; then
        warn "missing generated $config_dir/hypr/hyprlock.conf (lock screen may not work as configured)"
    else
        log "generated: ${config_dir}/hypr/hyprlock.conf"
    fi
    [ "$crit_fail" -eq 0 ]
}

run_apply_phase() {
    local repo_dir="${1:?repo_dir required}" dry_run="${2:-0}"
    if [ "$dry_run" -eq 1 ]; then
        echo
        phase "dry-run: planned apply steps"
        log "would ensure state dirs under ${XDG_STATE_HOME:-$HOME/.local/state}/dots and ${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
        log "would apply pending migrations from $repo_dir/migrations (marker-based)"
        log "would generate themes/colors, hypr overrides, hypridle.conf, and hyprlock.conf"
        log "would verify critical generated runtime artifacts"
        return 0
    fi
    echo
    phase "apply: migrations and generated state"
    ensure_runtime_dirs
    apply_migrations_phase "$repo_dir"
    generate_runtime_state
    verify_generated_runtime
}
