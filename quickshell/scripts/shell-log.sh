#!/usr/bin/env bash
#
# shell-log.sh — read the log of the running Quickshell.
#
# Why this exists
# ---------------
# This shell's stdout and stderr are both /dev/null: Hyprland starts it from an
# autostart unit with no output attached. So nothing Quickshell prints ever
# reaches the journal --
#
#     journalctl --user -b _PID=<pid>            -> No entries
#     journalctl --user -b | grep -i quickshell -> only systemd's own
#                                                  start/stop lines and
#                                                  coredump records
#
# which makes "check the journal after a reload" a check that cannot fail. The
# shell writes its own log, and only there:
#
#     $XDG_RUNTIME_DIR/quickshell/by-pid/<pid>/log.log
#
# a symlink into by-id/<instance>/log.log. The directory is not a guess: the
# shell announces it as its third line, "Saving logs to
# .../by-id/<instance>/log.qslog". `log.qslog` is Quickshell's own structured
# log; `log.log` beside it is the same content as plain text, and is the one
# worth grepping. That text log carries the `Reloading configuration...` /
# `Configuration Loaded` / `ERROR:` lines that verification actually needs.
#
# Usage
# -----
#     shell-log.sh path                    # the resolved log path, nothing else
#     shell-log.sh tail [N]                # last N lines (default 20)
#     shell-log.sh errors [SINCE]          # ERROR lines, SINCE = "YYYY-MM-DD HH:MM:SS"
#     shell-log.sh --pid PID <mode> [...]  # read one specific instance instead
#
# `path` prints the path and only the path, so other tooling can do
# `tail -f "$(quickshell/scripts/shell-log.sh path)"` without parsing prose.
#
# Exit status
# -----------
#   0  did the work
#   1  no shell is running, or its log is missing/dangling/unreadable (one line
#      on stderr naming the exact path, never a stack trace)
#   2  bad arguments (rejected at this boundary, before anything is executed)
#   3  `errors` ran fine and matched nothing -- so that it can be *a check*.
#      A `grep` that cannot fail is the bug this script exists to fix.

set -euo pipefail

readonly DEFAULT_TAIL=20

usage() {
    cat <<'EOF'
Usage: shell-log.sh [--pid PID] {path|tail [N]|errors [SINCE]}

  path             print the resolved log path and nothing else
  tail [N]         last N lines of the log (default 20)
  errors [SINCE]   ERROR lines, optionally only those at or after
                   "YYYY-MM-DD HH:MM:SS". Exits 3 if nothing matched.

  --pid PID        read that instance instead of the oldest running one
  -h, --help       this text
EOF
}

die() {
    printf 'shell-log: %s\n' "$*" >&2
    exit 1
}

usage_error() {
    printf 'shell-log: %s\n' "$*" >&2
    usage >&2
    exit 2
}

# ---------------------------------------------------------------- allow-lists
# Everything this script accepts from the command line is matched against one
# of these before it reaches a comparison, an argv, or awk. Rejecting here is
# cheaper than sanitising later, and a leading zero is rejected along with the
# rest: `tail 08` is not a number anyone means, and quietly reading it as 8 is
# the sort of leniency that makes a check disagree with its author.
is_count()      { [[ $1 =~ ^[1-9][0-9]*$ ]]; }
is_pid()        { [[ $1 =~ ^[1-9][0-9]*$ ]]; }
is_timestamp()  { [[ $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; }

# Quickshell's own runtime dir, which is where every by-pid/by-id view lives.
# XDG_RUNTIME_DIR is honoured so this script stays testable against a
# scratch root without touching the live shell.
RUNTIME_ROOT="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
FORCE_PID=""

# ------------------------------------------------------------ pick the shell
# Lowest PID wins. PIDs are handed out ascending, so the oldest quickshell
# process is the one Hyprland started at session start; a scratch instance
# (`quickshell -c /tmp/whatever`) is by definition started afterwards and so
# always has a higher one. `pgrep`'s output order is not promised, so the list
# is sorted numerically rather than trusted.
#
# PIDs whose log is missing or dangling are skipped in favour of the next
# oldest, because the oldest shell may simply not have created its runtime
# directory yet. If *none* of them has a log, the oldest one's exact failure is
# reported -- that is the instance somebody started deliberately, and its
# failure is the interesting one. `--pid` overrides the whole rule.
LOG_PATH=""

log_path_for() {
    printf '%s/quickshell/by-pid/%s/log.log\n' "$RUNTIME_ROOT" "$1"
}

# Say precisely which of the four distinguishable failures happened, rather
# than reporting "log not found" and leaving the reader to guess whether the
# shell is early, dying, or pointed somewhere else. Wording is "PID N is live"
# rather than "quickshell is running as PID N" because with `--pid` the pid may
# be the caller's own mistake, and this message has to stay true either way.
diagnose_no_log() {
    local pid="$1"
    local dir="$RUNTIME_ROOT/quickshell/by-pid/$pid"
    local path="$dir/log.log"

    if [ ! -e "$dir" ] && [ ! -L "$dir" ]; then
        die "PID $pid is live but has no quickshell runtime directory yet: $dir does not exist"
    fi
    if [ -L "$dir" ] && [ ! -e "$dir" ]; then
        die "PID $pid is live but $dir is a dangling symlink (its target is gone)"
    fi
    if [ ! -e "$path" ]; then
        die "PID $pid is live but has written no log yet: $path does not exist"
    fi
    die "PID $pid is live but its log is not readable: $path"
}

resolve_log() {
    local pids=() pid

    if [ -n "$FORCE_PID" ]; then
        # -0 rather than a name lookup: with an explicit --pid the caller's
        # intent is "this one", and the pid is the only thing to check.
        if ! kill -0 "$FORCE_PID" 2>/dev/null; then
            die "no process with PID $FORCE_PID"
        fi
        pids=("$FORCE_PID")
    else
        if ! command -v pgrep >/dev/null 2>&1; then
            die "pgrep is not installed, so the running shell cannot be found"
        fi
        mapfile -t pids < <(pgrep -x quickshell 2>/dev/null | sort -n)
        if [ ${#pids[@]} -eq 0 ]; then
            die "no quickshell process is running (pgrep -x quickshell found nothing)"
        fi
    fi

    for pid in "${pids[@]}"; do
        if [ -r "$(log_path_for "$pid")" ]; then
            LOG_PATH="$(log_path_for "$pid")"
            return 0
        fi
    done

    diagnose_no_log "${pids[0]}"
}

# ------------------------------------------------------------------- the modes
# The level token sits in a 5-character, left-aligned field after the
# millisecond timestamp, so `ERROR:` has one space before it and ` INFO`/
# ` WARN` have two. Matching `[ \t]ERROR:` rather than `ERROR` matters: a WARN
# line quoting a D-Bus error name ("Error updating property ...") is not an
# error of ours, and counting it here would make `errors` disagree with the
# word in its name.
#
# The SINCE comparison is a lexicographic compare of the first 19 characters.
# That is only sound because the timestamp is fixed-width and zero-padded,
# which is why it is validated against a `YYYY-MM-DD HH:MM:SS` allow-list
# rather than handed to awk as something to parse. It travels in ENVIRON
# instead of `-v` because `-v` processes backslash escapes; the allow-list
# already excludes them, but the env route has no escape processing at all, so
# the string arrives byte-for-byte.
emit_errors() {
    local since="$1"
    local matched
    matched="$(
        QS_LOG_SINCE="$since" awk '
            /[ \t]ERROR:/ {
                if (ENVIRON["QS_LOG_SINCE"] == "" || substr($0, 1, 19) >= ENVIRON["QS_LOG_SINCE"])
                    print
            }
        ' "$LOG_PATH"
    )"
    if [ -z "$matched" ]; then
        if [ -n "$since" ]; then
            printf 'shell-log: no ERROR lines at or after %s in %s\n' "$since" "$LOG_PATH" >&2
        else
            printf 'shell-log: no ERROR lines in %s\n' "$LOG_PATH" >&2
        fi
        exit 3
    fi
    printf '%s\n' "$matched"
}

# ----------------------------------------------------------------- arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --pid)
            [ $# -ge 2 ] || usage_error "--pid needs a PID"
            is_pid "$2" || usage_error "--pid wants a positive integer, got: $2"
            FORCE_PID="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            usage_error "unknown option: $1"
            ;;
        *)
            break
            ;;
    esac
done

MODE="${1:-}"
if [ $# -gt 0 ]; then
    shift
fi

case "$MODE" in
    path)
        [ $# -eq 0 ] || usage_error "path takes no arguments"
        ;;
    tail)
        COUNT="$DEFAULT_TAIL"
        if [ $# -gt 0 ]; then
            is_count "$1" || usage_error "tail wants a positive integer line count, got: $1"
            COUNT="$1"
            shift
        fi
        [ $# -eq 0 ] || usage_error "tail takes at most one argument"
        ;;
    errors)
        SINCE=""
        if [ $# -gt 0 ]; then
            is_timestamp "$1" || usage_error "errors wants a \"YYYY-MM-DD HH:MM:SS\" timestamp, got: $1"
            SINCE="$1"
            shift
        fi
        [ $# -eq 0 ] || usage_error "errors takes at most one argument"
        ;;
    ""|-h|--help)
        usage >&2
        exit 2
        ;;
    *)
        usage_error "unknown mode: $MODE"
        ;;
esac

resolve_log

case "$MODE" in
    path)
        printf '%s\n' "$LOG_PATH"
        ;;
    tail)
        tail -n "$COUNT" -- "$LOG_PATH"
        ;;
    errors)
        emit_errors "$SINCE"
        ;;
esac
