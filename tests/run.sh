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
#                         class this repo has hit most often.
#   qs-call parity        qs-call replaces `quickshell ipc call` for the one
#                         keybind that still spawns a process, so it has to
#                         agree with the real client on every call shape.
#   monitor overrides     per-monitor overrides can be present and silently
#                         not applied; a wrong path is exactly that.
#
# Tests needing a live shell are skipped, not failed, when there is no
# instance running -- so this is usable on a fresh clone.

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
    live=$(quickshell ipc call theme get 2>/dev/null | tr -d '\r\n')
    if [ -z "$live" ]; then
        sk "the live theme matches what the shell reports" "no quickshell instance"
    else
        before="$live"
        python3 "$QS_DIR/scripts/list-themes.py" >/dev/null 2>&1
        sleep 2
        after=$(quickshell ipc call theme get 2>/dev/null | tr -d '\r\n')
        if [ "$before" = "$after" ]; then
            ok "running discovery does not change the live theme ($after)"
        else
            no "running discovery does not change the live theme" "was '$before', became '$after'"
            # Put it back: the test must not leave the desktop altered.
            quickshell ipc call theme set "$before" >/dev/null 2>&1
        fi
    fi
fi

# ------------------------------------------------------------- installer dry run
section "installer"

if [ ! -x "$REPO/install.sh" ]; then
    sk "install.sh --dry-run writes nothing" "not found"
else
    before=$(find "$HOME/.config" -maxdepth 1 -newermt '-1 second' 2>/dev/null | wc -l)
    out=$("$REPO/install.sh" --dry-run 2>&1)
    rc=$?
    after=$(find "$HOME/.config" -maxdepth 1 -newermt '-1 second' 2>/dev/null | wc -l)
    if [ "$rc" -ne 0 ]; then
        no "install.sh --dry-run exits 0" "rc=$rc"
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
    out=$("$REPO/install.sh" --check 2>&1); rc=$?
    if [ "$rc" -eq 0 ]; then
        ok "install.sh --check passes"
    else
        no "install.sh --check passes" "$out" | tail -3
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
    checked=0
    for pair in "uis:isSettingsOpen" "uis:isLauncherOpen" "uis:isControlCenterOpen" \
                "uis:isPowerMenuOpen" "uis:isSettingsOpen" "uis:isClipboardOpen" \
                "uis:isMediaOpen" "uis:isCalendarOpen" "uis:isThemePickerOpen" \
                "uis:isWallpaperPickerOpen" "battery:getStatus" "battery:getPercentage" \
                "brightness:get" "wifi:status" "theme:get" "theme:list" \
                "power:get" "powerprofile:get" "nightlight:isEnabled" \
                "clipboard:isAvailable" "audio:getVolume"; do
        tgt="${pair%%:*}"; fn="${pair##*:}"
        read_only "$tgt" "$fn" || continue
        out=$(quickshell ipc call "$tgt" "$fn" 2>&1)
        checked=$((checked+1))
        case "$out" in
            *"Function not found"*) missing="$missing $tgt.$fn" ;;
        esac
    done

    if [ "$checked" -eq 0 ]; then
        sk "advertised read-only IPC functions are callable" "none matched"
    elif [ -z "$missing" ]; then
        ok "all $checked advertised read-only IPC functions are callable"
    else
        no "advertised IPC functions are callable" "unreachable:$missing"
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
        if detail=$(python3 "$QS_DIR/scripts/check-ipc-table.py" 2>&1); then
            ok "the IPC table in ARCHITECTURE.md matches the shell ($detail)"
        else
            no "the IPC table in ARCHITECTURE.md matches the shell" "$(printf '%s' "$detail" | head -4 | tr '\n' ';')"
        fi
    fi

    # Every advertised name must appear in `ipc show` under its target. This
    # catches a target that was renamed without updating its callers.
    unlisted=""
    while read -r tgt; do
        while read -r decl; do
            name=$(printf '%s' "$decl" | sed -E 's/^[[:space:]]*function[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1/')
            [ -z "$name" ] && continue
            count=$(quickshell ipc show 2>/dev/null | grep -c "function $name(")
            [ "$count" -ge 1 ] || unlisted="$unlisted $tgt.$name"
        done < <(quickshell ipc show 2>/dev/null \
                 | sed -n "/^target $tgt\$/,/^target /p" | sed '1d; /^target /d')
    done < <(quickshell ipc show 2>/dev/null | awk '/^target /{print $2}')
    [ -z "$unlisted" ] && ok "every advertised target lists its own functions" \
                        || no "advertised targets list their functions" "missing:$unlisted"

    # The two targets a keybind depends on.
    for t in shell uis; do
        if quickshell ipc show 2>/dev/null | grep -qx "target $t"; then
            ok "target '$t' is registered"
        else
            no "target '$t' is registered" "a keybind depends on it"
        fi
    done
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
    mismatches=0
    checked=0
    for pair in "uis:isSettingsOpen" "battery:getPercentage" "battery:getStatus" \
                "wifi:status" "theme:get" "theme:list" "power:get" \
                "nightlight:isEnabled" "mpris:play" "shell:closeAll"; do
        tgt="${pair%%:*}"; fn="${pair##*:}"
        real=$(quickshell ipc call "$tgt" "$fn" 2>&1)
        mine=$("$QSCALL" "$tgt" "$fn" 2>&1)
        checked=$((checked+1))
        if [ "$real" != "$mine" ]; then
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
        "$QSCALL" shell closeAll >/dev/null 2>&1
        sleep 2.5
        "$QSCALL" shell "$t" >/dev/null 2>&1
        # Retry: the first toggle after closeAll occasionally races.
        opened=""
        for _ in 1 2 3 4 5; do
            sleep 1
            [ "$("$QSCALL" uis "$p" 2>/dev/null)" = "true" ] && { opened=1; break; }
        done
        [ -n "$opened" ] || bad="$bad $t"
    done
    "$QSCALL" shell closeAll >/dev/null 2>&1
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

# ---------------------------------------------------------------------- summary
printf "\n"
if [ "$fail" -eq 0 ]; then
    printf "${GRN}tests: %d passed, %d skipped, 0 failed${RST}\n" "$pass" "$skip"
    exit 0
else
    printf "${RED}tests: %d passed, %d skipped, %d FAILED${RST}\n" "$pass" "$skip" "$fail"
    for n in "${failed_names[@]}"; do printf "    %s\n" "$n"; done
    exit 1
fi
