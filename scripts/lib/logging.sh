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
    local status="${1:-unknown}" exit_code="${2:-0}" ended_at details_file json_file
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
    printf '%s\n' "$DOTS_LOG_FILE" > "$(dots_state_dir)/last-log.path" 2>/dev/null || true

    json_file="$(dots_log_dir)/${DOTS_RUN_NAME:-run}-last.summary.json"
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$json_file" "$(dots_state_dir)/last-summary.json" <<'PY' "$DOTS_RUN_NAME" "$status" "$exit_code" "$DOTS_RUN_STARTED_AT" "$ended_at" "$DOTS_LOG_FILE" "${DOTS_WARN_COUNT:-0}" "${DOTS_ERR_COUNT:-0}" "$(pwd)" "$(git -C "${REPO_DIR:-.}" rev-parse HEAD 2>/dev/null || true)"
import json, os, sys
out1, out2, name, status, exit_code, started, ended, log_file, warn_count, err_count, cwd, rev = sys.argv[1:13]
data = {
  "run_name": name,
  "status": status,
  "exit_code": int(exit_code),
  "started_at": started or None,
  "ended_at": ended or None,
  "log_file": log_file or None,
  "warn_count": int(warn_count),
  "err_count": int(err_count),
  "cwd": cwd,
  "repo_revision": rev or None,
}
for path in (out1, out2):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(tmp, path)
PY
    fi
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
