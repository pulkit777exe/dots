#!/usr/bin/env bash
# Lightweight run logging and persisted summary/results.

# shellcheck shell=bash

: "${DOTS_LOG_FILE:=}"
: "${DOTS_RUN_NAME:=run}"
: "${DOTS_RUN_STARTED_AT:=}"
: "${DOTS_LAST_SUMMARY_FILE:=}"

dots_now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date; }

dots_init_logging() {
    local name="${1:-run}"
    [ -n "${DOTS_LOG_FILE:-}" ] && return 0
    DOTS_RUN_NAME="$name"
    DOTS_RUN_STARTED_AT="$(dots_now_iso)"
    mkdir -p "$(dots_log_dir)" "$(dots_state_dir)" 2>/dev/null || true
    DOTS_LOG_FILE="$(dots_log_dir)/${name}-$(date +%Y%m%d-%H%M%S).log"
    DOTS_LAST_SUMMARY_FILE="$(dots_state_dir)/last-result.env"
    # Best-effort log capture; keep console behavior.
    exec > >(tee -a "$DOTS_LOG_FILE") 2>&1
    log "log: $DOTS_LOG_FILE"
}

dots_write_summary() {
    local status="${1:-unknown}" exit_code="${2:-0}" ended_at details_file
    ended_at="$(dots_now_iso)"
    mkdir -p "$(dots_state_dir)" "$(dots_log_dir)" 2>/dev/null || true
    details_file="$(dots_state_dir)/last-result.env"
    cat > "$details_file" <<EOF
DOTS_LAST_RUN_NAME=${DOTS_RUN_NAME:-run}
DOTS_LAST_STATUS=${status}
DOTS_LAST_EXIT_CODE=${exit_code}
DOTS_LAST_STARTED_AT=${DOTS_RUN_STARTED_AT:-}
DOTS_LAST_ENDED_AT=${ended_at}
DOTS_LAST_LOG_FILE=${DOTS_LOG_FILE:-}
DOTS_LAST_WARN_COUNT=${DOTS_WARN_COUNT:-0}
DOTS_LAST_ERR_COUNT=${DOTS_ERR_COUNT:-0}
EOF
    # Human-readable latest summary pointer
    printf '%s\n' "$DOTS_LOG_FILE" > "$(dots_state_dir)/last-log.path" 2>/dev/null || true
}

dots_finish_run() {
    local exit_code=$?
    local status="success"
    [ "$exit_code" -ne 0 ] && status="failed"
    dots_write_summary "$status" "$exit_code"
    if [ -n "${DOTS_LOG_FILE:-}" ]; then
        echo
        log "summary: status=$status exit=$exit_code log=$DOTS_LOG_FILE"
        log "last result: $(dots_state_dir)/last-result.env"
    fi
    return "$exit_code"
}
