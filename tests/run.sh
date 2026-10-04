#!/usr/bin/env bash
#
# tests/run.sh — contract tests.
#
# These check promises the repo makes in its documentation, not style. Each
# one exists because the thing it checks has actually been wrong:
#
#   theme round trip      publish-colors.py writes generated files that are
#                         gitignored, so nothing else would notice if a
#                         change to the palettes stopped reproducing them.
#   list-themes live      list-themes.py reported a stale `current` for a
#                         while, pointing the wallpaper picker at the wrong
#                         theme with no error anywhere.
#   installer dry run     a dry run that writes is worse than no dry run.
#   IPC contract          an IpcHandler target that does not resolve means a
#                         keybind that silently does nothing -- the failure
#                         class this repo has hit most often. Also that
#                         `clipboard list`'s reply arrives whole: it is the
#                         only reply big enough to exceed what the IPC socket
#                         can carry, it used to be truncated with both clients
#                         reporting a closed socket, and a function that
#                         dispatches perfectly is what made that invisible.
#   qs-call parity        qs-call replaces `quickshell ipc call` for the one
#                         keybind that still spawns a process, so it has to
#                         agree with the real client on every call shape.
#   theme tokens          AuthDialog.qml asked for Theme.colors.accentAlt, a
#                         key that exists in no palette, so a live polkit
#                         dialog rendered `undefined` and said nothing. Six
#                         separate JSON files, and nothing ever read them
#                         against the source that indexes them.
#   palette keys          a palette gaining a key the other five lack is the
#                         same drift, one theme and one release later.
#   monitor overrides     per-monitor overrides can be present and silently
#                         not applied; a wrong path is exactly that.
#
# Tests needing a live shell are skipped, not failed, when there is no
# instance running -- so this is usable on a fresh clone. When one *is*
# running, its IPC calls go through `qs`, which retries across a reload.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QS_DIR="$REPO/quickshell"

RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; DIM=$'\033[2m'; RST=$'\033[0m'

pass=0
fail=0
skip=0
failed_names=()

ok()   { pass=$((pass+1)); printf "    ${GRN}ok${RST}   %s\n" "$1"; }
no()   { fail=$((fail+1)); failed_names+=("$1"); printf "    ${RED}FAIL${RST} %s\n" "$1"; [ -n "${2:-}" ] && printf "         %s\n" "$2"; }
sk()   { skip=$((skip+1)); printf "    ${YEL}skip${RST} %s ${DIM}(%s)${RST}\n" "$1" "${2:-}"; }

section() { printf "\n${DIM}-- %s${RST}\n" "$1"; }

have() { command -v "$1" >/dev/null 2>&1; }

# Some checks need the live shell but make their own `quickshell ipc show`
# call, so `qs` cannot wrap them: install.sh --dry-run and --check both check
# that the keybinds' targets are registered, and check-ipc-table.py reads the
# whole table. Each was called without a retry and each failed when a reload
# landed inside it -- one said "no target for shell uis", another "no running
# quickshell instance", both of which are the reload talking.
#
# So give them the same deadline and let a failure be retried until it is spent.
# That is not a skip: all three are read-only (`--dry-run` writes nothing,
# `--check` only reads, check-ipc-table.py only reads the IPC), so running one
# twice changes nothing, and a genuine failure is deterministic -- it fails
# again immediately and is reported once QS_WAIT is up. The price of a real
# failure is the deadline, not the verdict.
#
# The one case that fails fast is a shell that is not coming back at all: if a
# probe cannot get an answer inside the deadline, waiting longer will not help,
# so say so now instead of spending the rest of it finding out.
QS_CMD_OUT=""
QS_CMD_STALLED=0
qs_cmd() {
    local rc started
    started=$SECONDS
    QS_CMD_STALLED=0
    while :; do
        # Ask first, so the command does not begin inside a gap it would then
        # be blamed for.
        qs quickshell ipc show
        if [ "$QS_STALLED" -eq 1 ]; then
            QS_CMD_STALLED=1
            return 1
        fi
        QS_CMD_OUT=$("$@" 2>&1); rc=$?
        [ "$rc" -eq 0 ] && return 0
        [ "$((SECONDS - started))" -ge "$QS_WAIT" ] && return "$rc"
    done
}

# Why a `qs_cmd` failed, in one line: either the shell never came back, or the
# command failed for its own reasons and its own output is the evidence.
qs_cmd_why() {
    if [ "$QS_CMD_STALLED" -eq 1 ]; then
        printf 'the shell never answered, so this could not be checked: %s' "$(qs_why $QS_WAIT)"
    else
        printf '%s' "$QS_CMD_OUT" | tail -3 | tr '\n' ';'
    fi
}

# ------------------------------------------------------------------- token audit
# Both palette checks below are python, read-only, and share one reporting
# contract: the script prints a one-line count on stdout and the offending
# references on stderr, and its exit status decides pass or fail. Each is run
# once, with stderr redirected to a file rather than merged into the summary --
# a merged stream would put "Theme.colors.accentAlt" into the ok() line.
#
# They are heredocs rather than a checked-in script because they exist only to
# be read next to the assertion they justify, and the whole check is ~40 lines.

# --------------------------------------------------------------- live-shell IPC
# Every assertion here that touches the running shell goes through `qs`.
#
# Why: an edit anywhere under quickshell/ makes Quickshell's watcher reload the
# config in place, and for the length of that gap the IPC socket answers every
# request -- at exit status *0* -- with this string instead of the reply:
QS_BUSY="Not ready to accept queries yet."
#
# This suite failed once for exactly that reason: `qs-call wifi status`
# answered with it, `quickshell ipc call wifi status` answered with the real
# JSON, and the parity check reported a broken IPC handler when the desktop was
# fine and the editor was mid-save. Measured here, the gap is 0.5-1.2s wide
# and is announced in the shell's own log (`INFO: Reloading configuration...`,
# then `INFO: Configuration Loaded`) at
# /run/user/$UID/quickshell/by-pid/<pid>/log.log -- which is also the file whose
# parsing belongs to whoever owns the log-reading helper, so nothing here reads
# it.
#
# The retry keys on that one string and on nothing else. Any other reply, and
# any nonzero exit, fails on the spot -- "Function not found" included, because
# the IPC contract test needs to see that. And because the gap also reports
# exit status 0, "is there a shell at all" (a skip) and "is it mid-reload" (a
# retry) stay separate questions: the skip gates below are unchanged.
QS_WAIT="${QS_WAIT:-10}"     # seconds one assertion may keep retrying
QS_EVERY="${QS_EVERY:-0.25}" # seconds between attempts
qs_retries=0                 # suite-wide, reported in the summary
QS_OUT=""                     # reply from the last attempt
QS_RC=0                       # exit status of the last attempt
QS_STALLED=0                  # 1 = the deadline expired while the shell was busy

qs() {
    local out started n=0
    started=$SECONDS
    QS_STALLED=0
    while :; do
        n=$((n+1))
        out=$("$@" 2>&1); QS_RC=$?
        case "$out" in
            *"$QS_BUSY"*)
                QS_OUT="$out"
                if [ "$((SECONDS - started))" -ge "$QS_WAIT" ]; then
                    QS_STALLED=1
                    return 1
                fi
                qs_retries=$((qs_retries+1))
                sleep "$QS_EVERY"
                ;;
            *)
                QS_OUT="$out"
                return 0
                ;;
        esac
    done
}

# The diagnosis for a call that never came back: how long we waited, and
# whether the shell answers *anything* now. The probe uses the same channel
# the assertion does, so it cannot contradict it.
qs_why() {
    local probe
    probe=$(quickshell ipc call uis isLauncherOpen 2>&1 | tr -d '\r\n')
    printf 'waited %ss, shell answered "%s" every time; right now it says: %s' \
        "$1" "$QS_BUSY" "${probe:-nothing}"
}

# ---------------------------------------------------------------- theme round trip
section "theme round trip"

# These run against a scratch XDG_CONFIG_HOME rather than the real one.
#
# The first version published into the live config to check determinism, and
# that changed the running desktop: Theme.qml watches colors/index.json and
# re-runs discovery when it moves, so writing it re-applied a theme. A
# contract test that edits the thing it is testing is not a test.
#
# publish-colors.py resolves its output from XDG_CONFIG_HOME, so pointing it
# at a scratch directory exercises the real code path and leaves the live
# config alone. The themes have to be copied in, since that is the input.
THEME_DIR="$REPO/colors/themes"
SCRATCH=""

if ! have python3; then
    sk "publish-colors is deterministic" "no python3"
elif [ -z "$(ls "$THEME_DIR" 2>/dev/null)" ]; then
    sk "publish-colors is deterministic" "no colors/themes"
else
    SCRATCH="$(mktemp -d)"
    mkdir -p "$SCRATCH/colors"
    cp -r "$THEME_DIR" "$SCRATCH/colors/themes"
    [ -f "$REPO/colors/index.json" ] && cp "$REPO/colors/index.json" "$SCRATCH/colors/index.json"

    all_ok=1
    count=0
    for t in $(ls "$THEME_DIR" 2>/dev/null); do
        [ -f "$THEME_DIR/$t/colors.json" ] || continue
        count=$((count+1))
        XDG_CONFIG_HOME="$SCRATCH" python3 "$QS_DIR/scripts/publish-colors.py" "$t" >/dev/null 2>&1
        a=$(md5sum "$SCRATCH/colors/colors.css" "$SCRATCH/colors/gtk.css" 2>/dev/null | awk '{print $1}' | tr '\n' ' ')
        XDG_CONFIG_HOME="$SCRATCH" python3 "$QS_DIR/scripts/publish-colors.py" "$t" >/dev/null 2>&1
        b=$(md5sum "$SCRATCH/colors/colors.css" "$SCRATCH/colors/gtk.css" 2>/dev/null | awk '{print $1}' | tr '\n' ' ')
        if [ -z "$a" ] || [ "$a" != "$b" ]; then
            no "publish-colors is deterministic" "theme $t differed between runs, or produced nothing"
            all_ok=0
        fi
    done
    [ "$all_ok" -eq 1 ] && ok "publish-colors is deterministic ($count themes)"

    # Every theme must produce output that actually parses as JSON, or the
    # shell reads nothing on startup.
    bad=""
    for t in $(ls "$THEME_DIR" 2>/dev/null); do
        [ -f "$THEME_DIR/$t/colors.json" ] || continue
        XDG_CONFIG_HOME="$SCRATCH" python3 "$QS_DIR/scripts/publish-colors.py" "$t" >/dev/null 2>&1
        python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$SCRATCH/colors/current.json" 2>/dev/null \
            || bad="$bad $t"
    done
    [ -z "$bad" ] && ok "every theme publishes valid JSON" || no "every theme publishes valid JSON" "invalid:$bad"

    rm -rf "$SCRATCH"
fi

# The live theme must be the one the shell is actually running, and must not
# drift when the discovery script is invoked. `quickshell ipc call theme get`
# is the authority here -- Theme.qml's resolveTheme prefers savedTheme from
# theme-state.json over index.json's `current`, so those two are allowed to
# disagree and only the first tells you what is on screen.
if ! have python3; then
    sk "the live theme matches what the shell reports" "no python3"
else
    # `ipc show` reports a mid-reload gap at exit status 0, so this gate still
    # means "a shell exists" and never turns a reload into a skip.
    if ! quickshell ipc show >/dev/null 2>&1; then
        sk "the live theme matches what the shell reports" "no quickshell instance"
    elif ! qs quickshell ipc call theme get; then
        no "the live theme matches what the shell reports" "$(qs_why $QS_WAIT)"
    else
        live=$(printf '%s' "$QS_OUT" | tr -d '\r\n')
        before="$live"
        python3 "$QS_DIR/scripts/list-themes.py" >/dev/null 2>&1
        sleep 2
        if ! qs quickshell ipc call theme get; then
            no "running discovery does not change the live theme" "$(qs_why $QS_WAIT)"
        else
            after=$(printf '%s' "$QS_OUT" | tr -d '\r\n')
            if [ "$before" = "$after" ]; then
                ok "running discovery does not change the live theme ($after)"
            else
                no "running discovery does not change the live theme" "was '$before', became '$after'"
                # Put it back: the test must not leave the desktop altered.
                quickshell ipc call theme set "$before" >/dev/null 2>&1
            fi
        fi
    fi
fi

# ------------------------------------------------------------- installer dry run
section "installer"

if [ ! -x "$REPO/install.sh" ]; then
    sk "install.sh --dry-run writes nothing" "not found"
else
    before=$(find "$HOME/.config" -maxdepth 1 -newermt '-1 second' 2>/dev/null | wc -l)
    qs_cmd "$REPO/install.sh" --dry-run
    rc=$?
    out=$QS_CMD_OUT
    after=$(find "$HOME/.config" -maxdepth 1 -newermt '-1 second' 2>/dev/null | wc -l)
    if [ "$QS_CMD_STALLED" -eq 1 ]; then
        no "install.sh --dry-run exits 0" "$(qs_cmd_why)"
    elif [ "$rc" -ne 0 ]; then
        # Show what it said, not just the status: rc=1 alone cannot tell a
        # reload from a broken installer, and install.sh's own error line does.
        no "install.sh --dry-run exits 0" "rc=$rc $(qs_cmd_why)"
    elif ! printf '%s' "$out" | grep -q "dry run"; then
        no "install.sh --dry-run says it is a dry run" "no 'dry run' in output"
    else
        ok "install.sh --dry-run exits 0 and announces itself"
    fi
    if [ "$before" = "$after" ]; then
        ok "install.sh --dry-run wrote nothing"
    else
        no "install.sh --dry-run wrote nothing" "$before -> $after entries in ~/.config"
    fi
fi

if [ ! -x "$REPO/install.sh" ]; then
    sk "install.sh refuses to run as root" "not found"
elif [ "$(id -u)" -eq 0 ]; then
    sk "install.sh refuses to run as root" "already root"
else
    qs_cmd "$REPO/install.sh" --check
    rc=$?
    if [ "$rc" -eq 0 ]; then
        ok "install.sh --check passes"
    else
        # `no ... | tail -3` looks like it reports the failure, but a pipeline
        # puts `no` in a subshell: the FAIL line is swallowed and the counter
        # never moves, so the suite printed 16 passed / 0 failed and exited 0
        # while `--check` was returning 1. Trim the detail first, then report.
        no "install.sh --check passes" "$(qs_cmd_why)"
    fi
fi

# ------------------------------------------------------------------ IPC contract
section "IPC contract"

if [ ! -x "$REPO/hypr/scripts/qs-call" ]; then
    sk "every advertised IPC function is callable" "qs-call not found"
elif ! quickshell ipc show >/dev/null 2>&1; then
    sk "every advertised IPC function is callable" "no quickshell instance"
else
    # Every function `ipc show` advertises must actually be callable.
    #
    # Two earlier versions of this check were wrong:
    #
    #  1. It called a deliberately nonexistent function and treated "Function
    #     not found" as a failure, which flagged all fifteen targets. That is
    #     the correct reply to a missing function, so it measured nothing.
    #
    #  2. It then called every zero-argument function it could find, which
    #     invoked theme:cycle() -- and the live theme walked the entire theme
    #     list, one step per run. It took three runs to notice, because
    #     "the tests pass" says nothing about what they touched.
    #
    # So: call the functions named explicitly below, chosen because they are
    # read-only, and verify dispatch on the rest by name alone. The bug class
    # worth catching is a target advertising a name it cannot dispatch, and
    # `ipc show` already proves the name is there; what it cannot prove is
    # that dispatch works, which is what the read-only calls below check.
    read_only() {
        case "$1:$2" in
            uis:isSettingsOpen|uis:isLauncherOpen|uis:isControlCenterOpen|\
            uis:isPowerMenuOpen|uis:isSettingsOpen|uis:isClipboardOpen|\
            uis:isMediaOpen|uis:isCalendarOpen|uis:isThemePickerOpen|\
            uis:isWallpaperPickerOpen|\
            battery:getStatus|battery:getPercentage|battery:isCharging|\
            brightness:get|brightness:getFor|\
            wifi:status|bluetooth:refresh|bluetooth:toggle|\
            theme:get|theme:list|theme:getWallpaper|\
            powerprofile:get|power:get|power:list|\
            nightlight:isEnabled|clipboard:list|clipboard:isAvailable|\
            mpris:play|mpris:pause|mpris:playPause|\
            audio:getVolume|shell:isLauncherOpen)
                return 0 ;;
            *) return 1 ;;
        esac
    }

    missing=""
    stalled=""
    checked=0
    for pair in "uis:isSettingsOpen" "uis:isLauncherOpen" "uis:isControlCenterOpen" \
                "uis:isPowerMenuOpen" "uis:isSettingsOpen" "uis:isClipboardOpen" \
                "uis:isMediaOpen" "uis:isCalendarOpen" "uis:isThemePickerOpen" \
                "uis:isWallpaperPickerOpen" "battery:getStatus" "battery:getPercentage" \
                "brightness:get" "wifi:status" "theme:get" "theme:list" \
                "power:get" "powerprofile:get" "nightlight:isEnabled" \
                "clipboard:isAvailable" "clipboard:list" "audio:getVolume"; do
        tgt="${pair%%:*}"; fn="${pair##*:}"
        read_only "$tgt" "$fn" || continue
        qs quickshell ipc call "$tgt" "$fn"
        out=$QS_OUT
        checked=$((checked+1))
        # A stalled call never produced a reply, so it is neither proof that
        # the target dispatches nor proof that it does not.
        [ "$QS_STALLED" -eq 1 ] && stalled="$stalled $tgt.$fn"
        case "$out" in
            *"Function not found"*) missing="$missing $tgt.$fn" ;;
        esac
    done

    if [ "$checked" -eq 0 ]; then
        sk "advertised read-only IPC functions are callable" "none matched"
    elif [ -n "$stalled" ]; then
        no "advertised IPC functions are callable" "$(qs_why $QS_WAIT) unanswered:$stalled"
    elif [ -z "$missing" ]; then
        ok "all $checked advertised read-only IPC functions are callable"
    else
        no "advertised IPC functions are callable" "unreachable:$missing"
    fi

    # `clipboard list` is the only reply in the tree big enough to exceed what
    # the IPC socket can carry, and it did: at a 750-entry history it declared
    # 433,018 bytes of UTF-16 against a 212,992-byte send buffer, delivered
    # between 219,264 and 255,808, and ended mid-string. Both clients reported
    # a peer-closed socket, nothing was logged shell-side, and the shell stayed
    # healthy -- so it was recorded as an accessor that returns empty.
    #
    # Adding it to the pair loop above cannot catch that, and this comment is
    # the reason it was there for so long: the loop only looks for "Function
    # not found", and dispatch never stopped working. The reply's *size* was
    # the bug, so this checks the reply instead -- that it parses as JSON
    # (a truncated reply does not) and that it is inside a ceiling stated
    # here. The ceiling is a canary rather than the bound: Clipboard.qml caps
    # the reply at 64 KiB, and 128 KiB is the line this suite draws so a
    # regression is caught before the transport truncates it again.
    #
    # Two failure shapes are reported separately because they are different
    # faults. Unparseable means the reply was cut off in transit. Over the
    # ceiling means it arrived whole but has grown past what it should be.
    # Both used to present as the same symptom, and neither is visible from
    # `ipc show`.
    CLIP_LIST_CEILING=$((128 * 1024))
    clip_shape=""
    if ! have python3; then
        sk "clipboard list returns a whole, bounded reply" "no python3"
    elif ! qs quickshell ipc call clipboard list; then
        # `qs` returns 0 whenever the shell answers with anything at all, so a
        # reply that is not the reply is caught below rather than here; this
        # branch is only the shell never answering.
        no "clipboard list returns a whole, bounded reply" "$(qs_why $QS_WAIT)"
    elif ! clip_shape=$(printf '%s' "$QS_OUT" | python3 -c '
import json, sys

# The reply is an object carrying the total and a bounded window of entries.
# A bare array is the pre-fix shape and is reported rather than accepted, so a
# revert to it fails here instead of reading as a smaller, tidier payload.
try:
    d = json.load(sys.stdin)
except Exception as e:
    print("not JSON: %s" % e)
    sys.exit(1)
if not isinstance(d, dict):
    print("top level is %s, not an object" % type(d).__name__)
    sys.exit(1)
missing = [k for k in ("total", "returned", "entries") if k not in d]
if missing:
    print("no %s in the reply" % ",".join(missing))
    sys.exit(1)
if not isinstance(d["entries"], list):
    print("entries is not a list")
    sys.exit(1)
if d["returned"] != len(d["entries"]):
    print("returned=%d but %d entries arrived" % (d["returned"], len(d["entries"])))
    sys.exit(1)
print("total=%d returned=%d" % (d["total"], d["returned"]))
' 2>&1); then
        no "clipboard list returns a whole, bounded reply" "$clip_shape"
    else
        clip_bytes=$(printf '%s' "$QS_OUT" | wc -c)
        if [ "$clip_bytes" -gt "$CLIP_LIST_CEILING" ]; then
            no "clipboard list returns a whole, bounded reply" \
               "$clip_bytes bytes is past this suite's $CLIP_LIST_CEILING-byte ceiling"
        else
            ok "clipboard list returns a whole, bounded reply ($clip_shape, $clip_bytes of $CLIP_LIST_CEILING bytes)"
        fi
    fi

    # The IPC table in ARCHITECTURE.md claims to be generated from
    # `ipc show`. It was not -- it had drifted in both directions, promising
    # 10 functions that do not exist (wifi forget, wifi getEthernet,
    # audio getSinks/getSources/listStreams/cycleOutput, mpris getActive/list,
    # bluetooth list/isEnabled, shell nextTheme/nextWallpaper) and omitting
    # 20 that do. So check it.
    doc="$QS_DIR/ARCHITECTURE.md"
    if [ ! -f "$doc" ]; then
        sk "the IPC table in ARCHITECTURE.md matches the shell" "no ARCHITECTURE.md"
    else
        # Writes a one-line summary to stdout on success, the differing
        # targets to stderr on failure. Its exit status is the only thing
        # consulted, so the ok/fail branch must read *that* status and not
        # the status of a `||` chain -- an earlier version did, and printed
        # both a FAIL and an ok line for the same check.
        # Through `qs_cmd` because it reads `ipc show` itself, and a reload
        # landing inside it reads as "no running quickshell instance".
        qs_cmd python3 "$QS_DIR/scripts/check-ipc-table.py"
        rc=$?
        if [ "$QS_CMD_STALLED" -eq 1 ]; then
            no "the IPC table in ARCHITECTURE.md matches the shell" "$(qs_cmd_why)"
        elif [ "$rc" -eq 0 ]; then
            ok "the IPC table in ARCHITECTURE.md matches the shell ($QS_CMD_OUT)"
        else
            no "the IPC table in ARCHITECTURE.md matches the shell" "$(printf '%s' "$QS_CMD_OUT" | head -4 | tr '\n' ';')"
        fi
    fi

    # Every advertised name must appear in `ipc show` under its target. This
    # catches a target that was renamed without updating its callers.
    #
    # `ipc show` is read once: it cannot change while the suite runs, and the
    # original asked for a fresh copy per function -- 93 process launches for
    # one constant string, each of which could land in a reload gap.
    unlisted=""
    if ! qs quickshell ipc show; then
        no "advertised targets list their functions" "$(qs_why $QS_WAIT)"
    else
        show=$QS_OUT
        while read -r tgt; do
            while read -r decl; do
                name=$(printf '%s' "$decl" | sed -E 's/^[[:space:]]*function[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1/')
                [ -z "$name" ] && continue
                count=$(printf '%s\n' "$show" | grep -c "function $name(")
                [ "$count" -ge 1 ] || unlisted="$unlisted $tgt.$name"
            done < <(printf '%s\n' "$show" \
                     | sed -n "/^target $tgt\$/,/^target /p" | sed '1d; /^target /d')
        done < <(printf '%s\n' "$show" | awk '/^target /{print $2}')
        [ -z "$unlisted" ] && ok "every advertised target lists its own functions" \
                            || no "advertised targets list their functions" "missing:$unlisted"

        # The two targets a keybind depends on.
        for t in shell uis; do
            if printf '%s\n' "$show" | grep -qx "target $t"; then
                ok "target '$t' is registered"
            else
                no "target '$t' is registered" "a keybind depends on it"
            fi
        done
    fi
fi

# ------------------------------------------------------------------ qs-call parity
section "qs-call parity"

QSCALL="$REPO/hypr/scripts/qs-call"
if [ ! -x "$QSCALL" ]; then
    sk "qs-call matches the real client" "not found"
elif ! quickshell ipc show >/dev/null 2>&1; then
    sk "qs-call matches the real client" "no quickshell instance"
else
    # (target, function) pairs covering every reply shape: void, bool,
    # int-as-string, short JSON, and a longer JSON payload.
    #
    # `clipboard:list` is in this list for the length, not the shape: it is
    # the largest reply in the tree at about 65 KB, an order of magnitude
    # past every other pair here, and it is the one call that has crossed
    # `unpack()`'s framing rather than just its type. It compares equal only
    # if the fast path carries all of it -- a fast path that assembled a
    # reply a chunk short would fail here with a difference, where the
    # "Function not found" sweep in the section above would not notice.
    #
    # This is the check a reload gap broke. Two clients, called back to back:
    # a reload that starts between them hands one of them the "not ready"
    # reply and the other the real one, which is a mismatch with nothing wrong
    # anywhere. So both are called through `qs`, which does not return until it
    # has an answered reading of each -- and a mismatch after that is real.
    mismatches=0
    checked=0
    for pair in "uis:isSettingsOpen" "battery:getPercentage" "battery:getStatus" \
                "wifi:status" "theme:get" "theme:list" "power:get" \
                "nightlight:isEnabled" "mpris:play" "clipboard:list" \
                "shell:closeAll"; do
        tgt="${pair%%:*}"; fn="${pair##*:}"
        qs quickshell ipc call "$tgt" "$fn"; real=$QS_OUT
        qs "$QSCALL" "$tgt" "$fn"; mine=$QS_OUT
        checked=$((checked+1))
        if [ "$QS_STALLED" -eq 1 ]; then
            no "qs-call $tgt.$fn" "$(qs_why $QS_WAIT)"
            mismatches=$((mismatches+1))
        elif [ "$real" != "$mine" ]; then
            no "qs-call $tgt.$fn" "real: '${real:0:60}'  qs-call: '${mine:0:60}'"
            mismatches=$((mismatches+1))
        fi
    done
    [ "$mismatches" -eq 0 ] && ok "qs-call matches the real client on $checked call shapes"
fi

# --------------------------------------------------------------- lint and audit
section "static checks"

if [ -x "$REPO/scripts/lint.sh" ]; then
    if "$REPO/scripts/lint.sh" >/dev/null 2>&1; then
        ok "scripts/lint.sh is clean"
    else
        no "scripts/lint.sh is clean" "run scripts/lint.sh for detail"
    fi
else
    sk "scripts/lint.sh is clean" "not found"
fi

# ------------------------------------------------------------------- surfaces
section "surfaces (needs a live shell)"

if [ ! -x "$QSCALL" ] || ! quickshell ipc show >/dev/null 2>&1; then
    sk "every surface opens and closes" "no quickshell instance"
else
    bad=""
    for pair in "toggleControlCenter:isControlCenterOpen" \
                "toggleSettings:isSettingsOpen" \
                "toggleLauncher:isLauncherOpen" \
                "toggleClipboard:isClipboardOpen" \
                "toggleMedia:isMediaOpen" \
                "toggleCalendar:isCalendarOpen" \
                "togglePowerMenu:isPowerMenuOpen" \
                "toggleThemePicker:isThemePickerOpen" \
                "toggleWallpaperPicker:isWallpaperPickerOpen"; do
        t="${pair%%:*}"; p="${pair##*:}"
        qs "$QSCALL" shell closeAll
        sleep 2.5
        qs "$QSCALL" shell "$t"
        # Retry: the first toggle after closeAll occasionally races. The inner
        # probe is also wrapped, so a reload inside those five seconds is not
        # read as "this surface does not open".
        opened=""
        for _ in 1 2 3 4 5; do
            sleep 1
            qs "$QSCALL" uis "$p"
            [ "$QS_OUT" = "true" ] && { opened=1; break; }
        done
        [ -n "$opened" ] || bad="$bad $t"
    done
    qs "$QSCALL" shell closeAll
    if [ -z "$bad" ]; then
        ok "all nine surfaces open and close"
    else
        no "all nine surfaces open" "failed:$bad"
    fi
fi

# ------------------------------------------------------------------ monitor files
section "per-monitor overrides"

MON="$QS_DIR/monitors"
if [ ! -d "$MON" ]; then
    sk "monitor override files parse" "no monitors/ dir"
else
    bad=""
    for f in "$MON"/*.json; do
        [ -e "$f" ] || continue
        if ! python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if isinstance(d,dict) else 1)' "$f" 2>/dev/null; then
            bad="$bad $(basename "$f")"
        fi
    done
    if [ -z "$bad" ]; then
        ok "monitor override files are valid JSON"
    else
        no "monitor override files parse" "invalid:$bad"
    fi
fi

# ------------------------------------------------------------------ theme tokens
section "theme tokens"

# AuthDialog.qml asked for Theme.colors.accentAlt. No palette has an accentAlt
# -- not one of the six -- so on a live polkit dialog the pressed state bound to
# `undefined` and rendered as nothing, and nothing anywhere reported it. It
# shipped because the palettes are six independent JSON files and nothing ever
# read them against the QML that indexes them.
#
# So: collect every `Theme.colors.<key>` in the tree and require every key to
# exist in every palette. Read-only -- no shell, no network, no writes.
#
# Comments are stripped first, for the same reason scripts/lint.sh strips them:
# a token documented in a comment is an example, not a reference. The index
# forms are handled explicitly rather than ignored -- a quoted key is checked
# like any other, and a computed key cannot be checked, so it is reported as
# unsupported and fails, which is the point: a form this cannot see is a hole
# in the check, and it should be loud rather than green.
if [ -z "$(ls "$THEME_DIR"/*/colors.json 2>/dev/null)" ]; then
    sk "every Theme.colors key exists in every palette" "no colors/themes/*/colors.json"
elif ! have python3; then
    sk "every Theme.colors key exists in every palette" "no python3"
else
    # Two things are collected: every `Theme.colors.<key>` in the tree, and
    # every palette's key set. The verdict is the intersection -- a key used by
    # QML but missing from a palette is the bug that shipped. The counts are
    # printed either way, so a run that stops finding references is visible
    # rather than silently vacuous.
    err=$(mktemp)
    if summary=$(python3 - "$QS_DIR" "$THEME_DIR" 2>"$err" <<'PY'
import json, pathlib, re, sys

qs_dir, theme_dir = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])

palettes = {}
for path in sorted(theme_dir.glob("*/colors.json")):
    try:
        palettes[path.parent.name] = json.loads(path.read_text())
    except (OSError, ValueError) as e:
        print(f"{path}: unreadable palette ({e})", file=sys.stderr)
        sys.exit(1)

# Comments are stripped so a token written as an example in a doc comment is
# not mistaken for a use. `file://` survives because the scan is per-line and
# only `//` preceded by whitespace-ish starts a comment; see strip_line.
def strip_line(line):
    out, i, in_str = [], 0, False
    while i < len(line):
        c = line[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < len(line):
                out.append(line[i + 1]); i += 2; continue
            if c == '"':
                in_str = False
            i += 1; continue
        if c == '"':
            in_str = True; out.append(c); i += 1; continue
        if line.startswith("//", i):
            break
        if line.startswith("/*", i):
            break
        out.append(c); i += 1
    return "".join(out)

DOT = re.compile(r"Theme\.colors\.([A-Za-z_][A-Za-z0-9_]*)")
INDEX = re.compile(r"Theme\.colors\s*\[\s*([^\]]*)\]")

refs = []       # (file, line, key)
unsupported = []  # computed index access: cannot be checked
qml_files = 0

for path in sorted(qs_dir.rglob("*.qml")):
    qml_files += 1
    for n, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        code = strip_line(line)
        for m in DOT.finditer(code):
            refs.append((path, n, m.group(1)))
        for m in INDEX.finditer(code):
            expr = m.group(1).strip()
            # A quoted literal is checkable; anything computed is not, and
            # silently ignoring it is how this class of bug gets through.
            lit = re.fullmatch(r"""["']([A-Za-z_][A-Za-z0-9_]*)["']""", expr)
            if lit:
                refs.append((path, n, lit.group(1)))
            else:
                unsupported.append(f"{path.relative_to(qs_dir.parent)}:{n}: Theme.colors[{expr}]")

bad = []
for path, n, key in sorted(set(refs)):
    absent = sorted(name for name, pal in palettes.items() if key not in pal)
    if absent:
        bad.append(f"{path.relative_to(qs_dir.parent)}:{n}: Theme.colors.{key} "
                   f"not in {','.join(absent)}")

for u in sorted(set(unsupported)):
    bad.append(f"{u}: computed key, not checked by this test")

keys = sorted({k for _, _, k in refs})
for line in bad:
    print(line, file=sys.stderr)

if not refs:
    print("no Theme.colors references found -- the scan is wrong, not the tree",
          file=sys.stderr)
    sys.exit(1)

print(f"{len(refs)} refs, {len(keys)} keys, {len(palettes)} palettes"
      + (f", {len(set(unsupported))} computed access(es) unsupported" if unsupported else ""))
sys.exit(1 if bad else 0)
PY
    ); then
        ok "every Theme.colors key exists in every palette ($summary)"
    else
        no "every Theme.colors key exists in every palette" "$(head -4 "$err" | tr '\n' ';')"
    fi
    rm -f "$err"
fi

# The other half of the same class: a key that exists in one palette and not in
# the others. Nothing renders wrong the day it is added -- the shell reads
# whichever palette is current -- so it is invisible until a theme switch, on
# a palette that was not the one edited.
if [ -z "$(ls "$THEME_DIR"/*/colors.json 2>/dev/null)" ]; then
    sk "every palette defines the same keys" "no colors/themes/*/colors.json"
elif ! have python3; then
    sk "every palette defines the same keys" "no python3"
else
    err=$(mktemp)
    if summary=$(python3 - "$THEME_DIR" 2>"$err" <<'PY'
import json, pathlib, sys

theme_dir = pathlib.Path(sys.argv[1])
palettes, bad = {}, []
for path in sorted(theme_dir.glob("*/colors.json")):
    try:
        palettes[path.parent.name] = set(json.loads(path.read_text()))
    except (OSError, ValueError) as e:
        print(f"{path}: unreadable palette ({e})", file=sys.stderr)
        sys.exit(1)

if len(palettes) < 2:
    print("fewer than two palettes -- nothing to compare", file=sys.stderr)
    sys.exit(1)

# Compare against the union, so a key missing from three palettes is reported
# once with all three named rather than three times pairwise.
union = set().union(*palettes.values())
for name, keys in sorted(palettes.items()):
    missing = sorted(union - keys)
    if missing:
        bad.append(f"{name}: missing {','.join(missing)}")

for line in bad:
    print(line, file=sys.stderr)
print(f"{len(palettes)} palettes, {len(union)} distinct keys, "
      + ("identical key sets" if not bad else f"{len(bad)} divergent"))
sys.exit(1 if bad else 0)
PY
    ); then
        ok "every palette defines the same keys ($summary)"
    else
        no "every palette defines the same keys" "$(head -4 "$err" | tr '\n' ';')"
    fi
    rm -f "$err"
fi

# ---------------------------------------------------------------------- summary
printf "\n"
if [ "$fail" -eq 0 ]; then
    printf "${GRN}tests: %d passed, %d skipped, 0 failed${RST}\n" "$pass" "$skip"
    [ "$qs_retries" -eq 0 ] || printf "${DIM}    (%d IPC retries across a shell reload)${RST}\n" "$qs_retries"
    exit 0
else
    printf "${RED}tests: %d passed, %d skipped, %d FAILED${RST}\n" "$pass" "$skip" "$fail"
    for n in "${failed_names[@]}"; do printf "    %s\n" "$n"; done
    exit 1
fi
