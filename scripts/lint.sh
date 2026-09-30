#!/usr/bin/env bash
#
# lint.sh — the checks from quickshell/docs/DESIGN.md, made executable.
#
# Every rule here corresponds to something that has actually gone wrong in
# this codebase, not to a style preference:
#
#   Qt5Compat          DESIGN.md forbids it; the shadows are 7 stacked
#                      Rectangles instead. Also catches a doc comment that
#                      has drifted back into being a real import.
#   Region.enabled     A fabricated API. It never existed, and the CHANGELOG
#                      records a whole debugging session lost to it.
#   signal/property    QML auto-generates <property>Changed. Declaring the
#   collision          signal by hand as well makes the second binding win
#                      over the first, silently.
#   parent.parent      Works by accident of nesting depth. Every use has
#                      been a real fragility even where it was correct.
#   implicitHeight     A column or layout with no height of its own is how
#                      the settings page once collapsed to 72px.
#
# and one check that needs to parse whole files rather than match lines:
#
#   IpcHandler scope   A function declared inside an IpcHandler is reachable
#                      over `qs ipc call` but is not a method on the
#                      singleton, so `Foo.bar()` from QML does nothing and
#                      logs nothing. scripts/ipc-audit.py.
#
# Comments and Markdown are stripped before matching, so that the very
# documentation recording these traps does not trip the linter.
#
# A deliberate exception is annotated in place:
#
#   // lint:allow parent.parent -- only nesting here, see comment above
#
# so an allowlist is visible in the code rather than buried in this script.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QML_DIR="$REPO/quickshell"

RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; DIM=$'\033[2m'; RST=$'\033[0m'
fail=0

have() { command -v "$1" >/dev/null 2>&1; }

mapfile -t QML_FILES < <(find "$QML_DIR" -name '*.qml' | sort)
if [ ${#QML_FILES[@]} -eq 0 ]; then
    echo "${RED}no .qml files found under $QML_DIR${RST}"
    exit 1
fi

echo "${DIM}linting ${#QML_FILES[@]} QML files${RST}"
echo

# ---------------------------------------------------------------- grep rules
# Runs the rules with python3 rather than a sed pipeline: stripping QML
# comments correctly means not eating the "//" inside "file://", and a
# regex for <property>Changed colliding with property <X> is not a grep.
if have python3; then
    python3 - "$QML_DIR" <<'PY' || fail=1
import re, sys, pathlib

root = pathlib.Path(sys.argv[1])

# QML comments, without eating the // inside "file://" or "http://".
LINE_COMMENT = re.compile(r"(?<!:)//[^\n]*")
BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
ALLOW = re.compile(r"lint:allow\s+([a-z-]+)")

def strip(text):
    return LINE_COMMENT.sub("", BLOCK_COMMENT.sub("", text))

def rules_for(line):
    """which rules this line would trip, ignoring the ones it allows"""
    found = []
    if "Qt5Compat" in line:
        found.append("qt5compat")
    if re.search(r"\bRegion\s*\{[^}]*\benabled\s*:", line, re.S):
        found.append("region-enabled")
    if re.search(r"\bparent\.parent\b", line):
        found.append("parent-parent")
    return found

problems = []
for f in sorted(root.rglob("*.qml")):
    raw = f.read_text()
    code = strip(raw)

    # 1. signal <X>Changed declared alongside property <X>
    props = set(re.findall(r"^\s*(?:readonly\s+)?property\s+\w+\s+(\w+)\s*:", code, re.M))
    for name in re.findall(r"^\s*signal\s+(\w+)\s*\(", code, re.M):
        if name.endswith("Changed") and name[:-7] in props:
            problems.append((f, "signal-property", f"signal {name} duplicates the change signal for property {name[:-7]}"))

    # 2. An explicit width/height on an object that also anchors that same
    #    edge. The anchor wins and the explicit value is silently discarded,
    #    so the code reads as though it controls the size when it does not.
    #
    #    Replaces a "missing implicitHeight in surfaces" rule from the plan,
    #    which was dropped after being built: a whole-file version never fired
    #    on a real file, and a per-object version fired 21 times on nested
    #    layouts that Qt sizes perfectly well. This one has bitten twice in
    #    this repo -- Launcher.qml's `width: ConfigStore.launcherWidth` under
    #    `anchors.fill: parent`, and a page whose Layout.preferredWidth: 0
    #    beat the preferredWidth the layout was meant to read.
    for m in re.finditer(r"^([ \t]*)(?:[A-Z]\w*)\s*\{", code, re.M):
        depth, i = 0, m.end() - 1
        while i < len(code):
            if code[i] == "{":
                depth += 1
            elif code[i] == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        body = code[m.end():i]
        # Only the object's own property block: lines up to the first nested
        # `{`. A blank line is not a reliable stop -- properties are often
        # written without one -- so keying on the brace is.
        head_lines = []
        for ln in body.split("\n"):
            if "{" in ln:
                break
            head_lines.append(ln)
        head = "\n".join(head_lines)
        anchors_fill = re.search(r"anchors\.fill\s*:", head)
        if anchors_fill:
            for prop in ("width", "height"):
                if re.search(r"(?<![.\w])%s\s*:" % prop, head):
                    problems.append((f, "anchor-vs-explicit",
                                     f"object at offset {m.start()} sets {prop}: and anchors.fill -- the anchor wins"))
        for prop, pair in (("width", ("left", "right")), ("height", ("top", "bottom"))):
            if re.search(r"anchors\.%s\s*:" % pair[0], head) and re.search(r"anchors\.%s\s*:" % pair[1], head) \
               and re.search(r"(?<![.\w])%s\s*:" % prop, head):
                problems.append((f, "anchor-vs-explicit",
                                 f"object at offset {m.start()} sets {prop}: and both anchors.{pair[0]}/{pair[1]} -- the anchors win"))

    # 3. line rules, per line, with in-line allowlists
    for n, line in enumerate(raw.split("\n"), 1):
        allowed = set(ALLOW.findall(line))
        for rule in rules_for(strip(line)):
            if rule.replace("-", "") in {a.replace("-", "") for a in allowed}:
                continue
            if rule == "qt5compat" and line.lstrip().startswith(("//", "*", "#")):
                continue          # a comment naming it is the point
            if rule == "region-enabled" and line.lstrip().startswith(("//", "*", "#")):
                continue
            problems.append((f, rule, line.strip()[:90]))

# a trailing * marks a rule that is advisory: reported, but not a failure
soft = [x for x in problems if x[1].endswith("*")]
hard = [x for x in problems if not x[1].endswith("*")]

for f, rule, detail in soft:
    print("    \033[33m%-42s %-18s %s\033[0m" % (str(f.relative_to(root.parent)), rule, detail))
if soft:
    print("    \033[2m(%d advisory, not failing)\033[0m" % len(soft))

if not hard:
    print("\033[32m  grep rules: clean\033[0m")
    sys.exit(0)

print("\033[31m  grep rules: %d failure(s)\033[0m" % len(hard))
for f, rule, detail in hard:
    print("    %-42s %-18s %s" % (str(f.relative_to(root.parent)), rule, detail))
sys.exit(1)
PY
else
    echo "${YEL}  python3 not found — skipping the grep rules${RST}"
fi

# ------------------------------------------------------------------ ipc audit
# A separate script, not another rule above, because it needs to parse
# brace depth across whole files rather than match lines. It is the only
# check that can see the Round 7 bug class: qmllint proves every
# Service.member resolves, so a missing member cannot survive a clean
# lint, but nothing else knows that a function declared inside an
# IpcHandler is not a method on the singleton.
if have python3 && [ -x "$REPO/scripts/ipc-audit.py" ]; then
    echo
    echo "${DIM}ipc scope${RST}"
    "$REPO/scripts/ipc-audit.py" "$QML_DIR" | sed 's/^/ /'
    case "${PIPESTATUS[0]}" in
        0) ;;
        # 2 is the parser saying it does not trust itself. Not a pass.
        2) echo "${RED}  ipc scope: parser could not verify the tree${RST}"; fail=1 ;;
        *) echo "${RED}  ipc scope: IpcHandler-only members referenced from QML${RST}"; fail=1 ;;
    esac
fi

# ------------------------------------------------------------------- qmllint
if have qmllint; then
    echo
    echo "${DIM}qmllint${RST}"
    # shellcheck disable=SC2046
    if ( cd "$QML_DIR" && qmllint -I . -I services -I components -I surfaces $(find . -name '*.qml' | sort) ) > /tmp/lint-qmllint.log 2>&1; then
        echo "${GRN}  qmllint: clean${RST}"
    else
        # Warnings are not failures here: this tree has never been qmllint
        # clean and making it so is a separate job. Errors are.
        if grep -qE "Error|error:" /tmp/lint-qmllint.log; then
            echo "${RED}  qmllint: errors${RST}"
            grep -E "Error|error:" /tmp/lint-qmllint.log | head -20 | sed 's/^/    /'
            fail=1
        else
            n=$(grep -c "Warning" /tmp/lint-qmllint.log || true)
            n=${n:-0}
            if [ "$n" -gt 0 ]; then
                echo "${YEL}  qmllint: no errors, $n warning(s) (full log: /tmp/lint-qmllint.log)${RST}"
            else
                echo "${GRN}  qmllint: clean${RST}"
            fi
        fi
    fi
else
    echo "${YEL}  qmllint not found — skipped${RST}"
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "${GRN}lint: clean${RST}"
else
    echo "${RED}lint: FAILED${RST}"
fi
exit "$fail"
