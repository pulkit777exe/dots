#!/usr/bin/env bash

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

QS_CMD_OUT=""
QS_CMD_STALLED=0
qs_cmd() {
    local rc started
    started=$SECONDS
    QS_CMD_STALLED=0
    while :; do
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

qs_cmd_why() {
    if [ "$QS_CMD_STALLED" -eq 1 ]; then
        printf 'the shell never answered, so this could not be checked: %s' "$(qs_why $QS_WAIT)"
    else
        printf '%s' "$QS_CMD_OUT" | tail -3 | tr '\n' ';'
    fi
}

QS_BUSY="Not ready to accept queries yet."
QS_WAIT="${QS_WAIT:-10}"
QS_EVERY="${QS_EVERY:-0.25}"
qs_retries=0
QS_OUT=""
QS_RC=0
QS_STALLED=0

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

qs_why() {
    local probe
    probe=$(quickshell ipc call uis isControlCenterOpen 2>&1 | tr -d '\r\n')
    printf 'waited %ss, shell answered "%s" every time; right now it says: %s' \
        "$1" "$QS_BUSY" "${probe:-nothing}"
}

section "theme round trip"

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

section "hypridle generator"

if ! have python3; then
    sk "hypridle conf is deterministic" "no python3"
else
    SCRATCH="$(mktemp -d)"
    mkdir -p "$SCRATCH/state/quickshell" "$SCRATCH/config"
    cat > "$SCRATCH/state/quickshell/settings.json" <<'EOF'
{"lockTimeoutSec": 90, "displayTimeoutSec": 200, "suspendTimeoutSec": 0,
 "idleSeparateCharging": true, "cLockTimeoutSec": 60,
 "cDisplayTimeoutSec": 120, "cSuspendTimeoutSec": 1800}
EOF
    gen() {
        XDG_STATE_HOME="$SCRATCH/state" XDG_CONFIG_HOME="$SCRATCH/config" \
            HYPRIDLE_AC_ONLINE="$1" python3 "$REPO/quickshell/scripts/generate-hypridle-conf.py" >/dev/null 2>&1
    }
    gen 0; a=$(md5sum "$SCRATCH/config/hypr/hypridle.conf" 2>/dev/null | awk '{print $1}')
    gen 0; b=$(md5sum "$SCRATCH/config/hypr/hypridle.conf" 2>/dev/null | awk '{print $1}')
    if [ -z "$a" ] || [ "$a" != "$b" ]; then
        no "hypridle conf is deterministic" "differed between runs, or produced nothing"
    else
        ok "hypridle conf is deterministic"
    fi
    if grep -q "timeout = 90" "$SCRATCH/config/hypr/hypridle.conf" \
        && ! grep -q "systemctl suspend" "$SCRATCH/config/hypr/hypridle.conf"; then
        ok "battery profile uses battery timeouts, suspend omitted at 0"
    else
        no "battery profile uses battery timeouts, suspend omitted at 0" "see generator"
    fi
    gen 1
    if grep -q "timeout = 60" "$SCRATCH/config/hypr/hypridle.conf" \
        && grep -q "timeout = 1800" "$SCRATCH/config/hypr/hypridle.conf"; then
        ok "charging profile switches on AC"
    else
        no "charging profile switches on AC" "see generator"
    fi
    rm -rf "$SCRATCH"
fi

if ! have python3; then
    sk "the live theme matches what the shell reports" "no python3"
else
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
                quickshell ipc call theme set "$before" >/dev/null 2>&1
            fi
        fi
    fi
fi

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
        no "install.sh --check passes" "$(qs_cmd_why)"
    fi
fi

section "IPC contract"

if ! quickshell ipc show >/dev/null 2>&1; then
    sk "every advertised IPC function is callable" "no quickshell instance"
else
    read_only() {
        case "$1:$2" in
            uis:isSettingsOpen|uis:isLauncherOpen|uis:isControlCenterOpen|\
            uis:isPowerMenuOpen|uis:isThemePickerOpen|uis:isWallpaperPickerOpen|\
            uis:isClipboardOpen|\
            brightness:get|wifi:status|theme:get|theme:list|theme:getWallpaper|\
            powerprofile:get|powerprofile:isAvailable|nightlight:isEnabled|\
            audio:getVolume|notifs:count|notifs:isDndEnabled)
                return 0 ;;
            *) return 1 ;;
        esac
    }

    missing=""
    stalled=""
    checked=0
    for pair in "uis:isSettingsOpen" "uis:isLauncherOpen" "uis:isControlCenterOpen" \
                "uis:isPowerMenuOpen" "uis:isThemePickerOpen" \
                "uis:isWallpaperPickerOpen" "uis:isClipboardOpen" \
                "brightness:get" "wifi:status" \
                "theme:get" "theme:list" "theme:getWallpaper" "powerprofile:get" \
                "powerprofile:isAvailable" "nightlight:isEnabled" \
                "audio:getVolume" "notifs:count" "notifs:isDndEnabled"; do
        tgt="${pair%%:*}"; fn="${pair##*:}"
        read_only "$tgt" "$fn" || continue
        qs quickshell ipc call "$tgt" "$fn"
        out=$QS_OUT
        checked=$((checked+1))
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

    doc="$QS_DIR/ARCHITECTURE.md"
    if [ ! -f "$doc" ]; then
        sk "the IPC table in ARCHITECTURE.md matches the shell" "no ARCHITECTURE.md"
    else
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

        for t in shell uis; do
            if printf '%s\n' "$show" | grep -qx "target $t"; then
                ok "target '$t' is registered"
            else
                no "target '$t' is registered" "a keybind depends on it"
            fi
        done
    fi
fi

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

section "surfaces (needs a live shell)"

if ! quickshell ipc show >/dev/null 2>&1; then
    sk "every surface opens and closes" "no quickshell instance"
else
    bad=""
    for pair in "toggleControlCenter:isControlCenterOpen" \
                "toggleSettings:isSettingsOpen" \
                "toggleLauncher:isLauncherOpen" \
                "togglePowerMenu:isPowerMenuOpen" \
                "toggleThemePicker:isThemePickerOpen" \
                "toggleWallpaperPicker:isWallpaperPickerOpen" \
                "toggleClipboard:isClipboardOpen"; do
        t="${pair%%:*}"; p="${pair##*:}"
        qs quickshell ipc call shell closeAll
        sleep 2.5
        qs quickshell ipc call shell "$t"
        opened=""
        for _ in 1 2 3 4 5; do
            sleep 1
            qs quickshell ipc call uis "$p"
            [ "$QS_OUT" = "true" ] && { opened=1; break; }
        done
        [ -n "$opened" ] || bad="$bad $t"
    done
    qs quickshell ipc call shell closeAll
    if [ -z "$bad" ]; then
        ok "all seven surfaces open and close"
    else
        no "all seven surfaces open" "failed:$bad"
    fi
fi

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

section "theme tokens"

if [ -z "$(ls "$THEME_DIR"/*/colors.json 2>/dev/null)" ]; then
    sk "every Theme.colors key exists in every palette" "no colors/themes/*/colors.json"
elif ! have python3; then
    sk "every Theme.colors key exists in every palette" "no python3"
else
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
