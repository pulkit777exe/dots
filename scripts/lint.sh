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
# and two rules that need the tree's own qmldir files as a table:
#
#   service-missing-   A file that names Theme or ConfigStore without importing
#   import             the module that declares them loads, passes qmllint
#                      ("Unqualified access"), and renders the wrong thing:
#                      five files once came in without `import "../services"`
#                      and drew black text on a dark fill. The quickshell
#                      imports check below cannot see it -- its table is
#                      `Quickshell.*` module URIs only.
#
# Comments and Markdown are stripped before matching, so that the very
# documentation recording these traps does not trip the linter.
#
# A deliberate exception is annotated in place:
#
#   // lint:allow parent.parent -- only nesting here, see comment above
#
# so an allowlist is visible in the code rather than buried in this script.
# `service-missing-import` is the one rule that is exempted per file rather
# than per line, since what it is about is a file's import block.

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
# An exemption names the rule it excuses, in the spelling the code uses
# (parent.parent) or the lint's own id (parent-parent), and an advisory
# rule's id carries a trailing `*`. Character-classing the name as
# [a-z-]+ accepted only the second spelling and silently dropped the `*`,
# so `parent.parent` was captured as `parent` and `color-literal*` as
# `color-literal` -- neither equal to the rule being exempted, and both
# exemptions then did nothing while looking correct in the source. Nothing
# in the tree used the annotation, so there was nothing to notice.
ALLOW = re.compile(r"lint:allow\s+([a-z-]+(?:\.[a-z-]+)?\*?)")

def norm(rule):
    """rule id and the annotation that excuses it differ only in spelling:
    `parent.parent` is the rule id `parent-parent`. The `*` is part of an
    advisory rule's id on both sides, so it must survive."""
    return re.sub(r"[.-]", "", rule)

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
            if norm(rule) in {norm(a) for a in allowed}:
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

# --------------------------------------------------------- quickshell imports
# Three questions about every `import Quickshell.X`, all from one table.
#
#   1 present      the module URI exists in the installed binary. An
#                  unresolvable `import Quickshell.X` is a load-time crash,
#                  not a lint error -- that is what Round 1's Qt5Compat
#                  import did, and what qmllint exits 0 with an empty log on.
#   2 used         the file names a Quickshell type without importing the
#                  module that provides it.
#   3 unused       the file imports a module whose types it never names.
#
# (2) and (3) are the same mistake from opposite ends, and the failure is
# already on record: services/Bluetooth.qml lost `import Quickshell.Io` as a
# dead import -- nothing else in the file used Io -- while still declaring an
# `IpcHandler`, which Quickshell.Io provides and Quickshell does not. The
# file stopped compiling, and because every service imports Bluetooth the
# whole configuration failed to load: Battery, BarConfig, BarConfigMonitors,
# Auth, AppLauncher, Surface, Island. Two reloads of a running desktop, and
# the shell's log was the only place it appeared.
#
# qmllint is structurally blind to this. It cannot resolve Quickshell.* types
# in this setup at all -- 2378 of its 2992 warnings here are `[import]` and
# `[unresolved-type]`, and `IpcHandler was not found` appears 15 times whether
# or not the file imports Quickshell.Io, so the warning carries no signal
# about which import is missing. Hence a table.
QS_BIN="$(command -v quickshell 2>/dev/null || true)"
if have python3; then
    echo
    echo "${DIM}quickshell imports${RST}"
    python3 - "$QML_DIR" "$QS_BIN" <<'PY' || fail=1
import pathlib, re, subprocess, sys

root = pathlib.Path(sys.argv[1])
binary = sys.argv[2] if len(sys.argv) > 2 else ""

LINE_COMMENT = re.compile(r"(?<!:)//[^\n]*")
BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
STRING = re.compile(r"\"[^\"\n]*\"|'[^'\n]*'")
IMPORT = re.compile(r"^\s*import\s+(Quickshell(?:\.[A-Za-z][A-Za-z0-9]*)*)(?:\s+as\s+([A-Za-z_]\w*))?\s*$", re.M)
PRAGMA = re.compile(r"^[ \t]*pragma\s+\w+.*$", re.M)

# module -> the types it provides, for Quickshell 0.3.1. Provenance: each
# type's own page at
# https://quickshell.outfoxxed.me/docs/v0.3.1/types/<Module>/<Type>/ names
# its module in the `import ...` line under the title (that is how
# ShellScreen came out as Quickshell rather than Quickshell.Wayland), and the
# module set is the set of Quickshell module URIs in the installed binary.
# Regenerate after a Qt bump:
#   strings "$(command -v quickshell)" | grep -oE '^Quickshell(\.[A-Za-z0-9]+)*$' | sort -u
#   https://quickshell.outfoxxed.me/docs/v<VER>/types/
# The 0.3.1 binary also carries a `Quickshell.X11` URI that the docs no longer
# list; no X11 type is used here, so none is tabulated.
TYPES = {
    "Quickshell": "BoundComponent ColorQuantizer DesktopAction DesktopEntries DesktopEntry EasingCurve Edges ElapsedTimer ExclusionMode FloatingWindow Intersection LazyLoader ObjectComparison ObjectModel PanelWindow PersistentProperties PopupAdjustment PopupAnchor PopupWindow QsMenuAnchor QsMenuButtonType QsMenuEntry QsMenuHandle QsMenuOpener QsWindow Quickshell QuickshellSettings Region RegionShape Reloadable Retainable RetainableLock Scope ScriptModel ShellRoot ShellScreen Singleton SystemClock TransformWatcher Variants",
    "Quickshell.Bluetooth": "Bluetooth BluetoothAdapter BluetoothAdapterState BluetoothDevice BluetoothDeviceState",
    "Quickshell.DBusMenu": "DBusMenuHandle DBusMenuItem",
    "Quickshell.Hyprland": "GlobalShortcut Hyprland HyprlandEvent HyprlandFocusGrab HyprlandMonitor HyprlandToplevel HyprlandWindow HyprlandWorkspace",
    "Quickshell.I3": "I3 I3Event I3IpcListener I3Monitor I3Workspace",
    "Quickshell.Io": "DataStream DataStreamParser FileView FileViewAdapter FileViewError IpcHandler JsonAdapter JsonObject Process Socket SocketServer SplitParser StdioCollector",
    "Quickshell.Networking": "ConnectionFailReason ConnectionState DeviceType NMSettings Network NetworkBackendType NetworkConnectivity NetworkDevice Networking WifiDevice WifiDeviceMode WifiNetwork WifiSecurityType WiredDevice",
    "Quickshell.Services.Greetd": "Greetd GreetdState",
    "Quickshell.Services.Mpris": "Mpris MprisLoopState MprisPlaybackState MprisPlayer",
    "Quickshell.Services.Notifications": "Notification NotificationAction NotificationCloseReason NotificationServer NotificationUrgency",
    "Quickshell.Services.Pam": "PamContext PamError PamResult",
    "Quickshell.Services.Pipewire": "Pipewire PwAudioChannel PwLink PwLinkGroup PwLinkState PwNode PwNodeAudio PwNodeLinkTracker PwNodePeakMonitor PwNodeType PwObjectTracker",
    "Quickshell.Services.Polkit": "AuthFlow PolkitAgent",
    "Quickshell.Services.SystemTray": "Category Status SystemTray SystemTrayItem",
    "Quickshell.Services.UPower": "PerformanceDegradationReason PowerProfile PowerProfiles UPower UPowerDevice UPowerDeviceState UPowerDeviceType",
    "Quickshell.Wayland": "BackgroundEffect IdleInhibitor IdleMonitor ScreencopyView ShortcutInhibitor Toplevel ToplevelManager WlSessionLock WlSessionLockSurface WlrKeyboardFocus WlrLayer WlrLayershell",
    "Quickshell.Widgets": "ClippingRectangle ClippingWrapperRectangle IconImage MarginWrapperManager WrapperItem WrapperManager WrapperMouseArea WrapperRectangle",
    "Quickshell.WindowManager": "ScreenProjection WindowManager Windowset WindowsetProjection",
}
PROVIDES = {t: m for m, ts in TYPES.items() for t in ts.split()}
ALT = "|".join(sorted(PROVIDES, key=len, reverse=True))

# A name counts as a use of a type only in a position where a missing import
# stops the file compiling: declared (`Process {`) or written as a
# property/signal/parameter type (`readonly property Process p: Process {`).
# A *namespace* reference (`Mpris.players`, `Quickshell.execDetached`) is
# deliberately not counted. Deleting the import there does not stop the file
# loading -- it degrades to a ReferenceError when that code runs -- so it is
# a different bug class from the one above, and a different change. It is a
# known blind spot with one live instance in the tree:
# surfaces/ControlCenter.qml:1667 and :2204 call `Quickshell.execDetached`
# with no `import Quickshell`, which resolves to nothing.
DECL = re.compile(r"(?<![\w.])(%s)\s*\{" % ALT)
PROPERTY = re.compile(r"\bproperty\s+(?:(?:required|readonly|default)\s+)*(%s)\b" % ALT)
PARAMETERS = re.compile(r"\b(?:signal\s+\w+|function\s+\w*)\s*\(([^)]*)\)")

# A .qml file of the same name shadows the Quickshell type of that name: QML
# resolves same-directory types and qmldir singletons with no import, and a
# singleton is *referenced* exactly as a type is, so
# `Bluetooth.enabled` in ControlPreview.qml is this repo's service and not
# Quickshell.Bluetooth's. Four names collide here (Bluetooth, Notification,
# Notifications, PowerProfile) and a bare-name grep cannot tell the two
# meanings apart, so it must not report them. The cost is that a genuine
# violation on one of those four names is not reported.
SHADOWED = {p.stem for p in root.rglob("*.qml")}

def hide(pattern, text):
    """blank a match in place, so reported line numbers stay real"""
    return pattern.sub(lambda m: re.sub(r"[^\n]", " ", m.group(0)), text)

errors, advisories, wanted = [], [], {}
for f in sorted(root.rglob("*.qml")):
    rel = f.relative_to(root.parent)
    code = hide(LINE_COMMENT, hide(BLOCK_COMMENT, hide(STRING, f.read_text())))
    imports = {m.group(1): m.group(2) for m in IMPORT.finditer(code)}
    # the import lines are not uses of the types, and `pragma Singleton` is a
    # keyword rather than a type reference
    body = hide(IMPORT, hide(PRAGMA, code))

    # (2) used but not imported -- an error, because the file will not compile
    for n, line in enumerate(body.split("\n"), 1):
        found = set(DECL.findall(line)) | set(PROPERTY.findall(line))
        for params in PARAMETERS.findall(line):
            found |= set(re.findall(r"(?<![\w.])(%s)\s+\w" % ALT, params))
        for t in sorted(found):
            if t in SHADOWED or PROVIDES[t] in imports:
                continue
            errors.append("%s:%d  %s needs `import %s`" % (rel, n, t, PROVIDES[t]))

    # (3) imported but unused -- advisory. An unused import is untidy, not
    # broken, so it is reported and does not fail the run. The test is
    # deliberately more generous than (2): any bare mention of one of the
    # module's types, including a namespace prefix. That is what makes
    # `import Quickshell.Io` in Bluetooth.qml come out *used*, on the strength
    # of the IpcHandler it does still declare.
    for mod, alias in sorted(imports.items()):
        names = "|".join(sorted(TYPES[mod].split(), key=len, reverse=True))
        used = re.search(r"(?<![\w.])(?:%s)\b" % names, body)
        if not used and alias:
            used = re.search(r"(?<![\w.])%s\s*\.\s*(?:%s)\b" % (re.escape(alias), names), body)
        if not used:
            advisories.append("%s  no type from %s" % (rel, mod))

    # every module the tree imports, used or not, still has to exist
    for mod in imports:
        wanted.setdefault(mod, []).append(str(rel))

# (1) present in the installed binary
missing = {}
if binary:
    # `strings` is line-delimited and every module URI is a registered QML
    # module name, so the test is an exact line match. Substring matching
    # would pass `Quickshell.I3` off as a present `Quickshell.Io`.
    have = set(subprocess.run(["strings", binary], capture_output=True,
                              text=True, check=True).stdout.split("\n"))
    missing = {m: v for m, v in wanted.items() if m not in have}

for e in errors:
    print("\033[31m    %s\033[0m" % e)
for m, files in sorted(missing.items()):
    where = sorted(set(files))
    tail = " (+%d more)" % (len(where) - 3) if len(where) > 3 else ""
    print("\033[31m    %s is not in %s -- imported by %s%s\033[0m"
          % (m, binary, ", ".join(where[:3]), tail))
for a in advisories:
    print("\033[33m    %s\033[0m" % a)
if advisories:
    print("\033[2m    (%d advisory: an unused import is untidy, not broken)\033[0m" % len(advisories))
if errors or missing:
    print("\033[31m  quickshell imports: %d error(s), %d missing module(s), %d advisory\033[0m"
          % (len(errors), len(missing), len(advisories)))
    sys.exit(1)
print("\033[32m  every Quickshell type the tree names is imported, and all %d module(s) it"
      "\n\033[32m  imports are in the binary\033[0m" % len(wanted))
PY
else
    echo "${YEL}  python3 not found - skipped the Quickshell import checks${RST}"
fi

# ------------------------------------------------------------ service imports
# The same question again, for this tree's own types instead of Quickshell's.
# A .qml that names a service singleton without importing the module that
# declares it loads, passes qmllint -- which says only "Unqualified access",
# a warning about 500 of which this tree already carries -- and renders the
# wrong thing. Five new files were missing `import "../services"` and drew black
# text on a dark fill, with nothing wrong anywhere to find. The table above
# covers `Quickshell.*` module URIs only, so none of this was in scope for it.
#
# Unlike the Quickshell table, this one is read out of the tree rather than
# written by hand: services/qmldir and modules/qmldir are the source of truth
# for what exists and for which directory declares it, so adding a singleton
# to a qmldir cannot leave the linter behind.
#
# Resolution has three shapes and the difference between them is the whole
# subtlety, so it is spelled out:
#
#   own directory     A file always sees its own directory with no import at
#                     all. That is how services/Theme.qml reads ConfigStore,
#                     and ten of the forty services files rely on it.
#   relative `"dir"`  A plain directory of files: every sibling .qml resolves
#                     through it, listed in the qmldir or not.
#   `qs.<path>`       A module import, relative to shell.qml's folder, and it
#   `import <uri>`    goes through the qmldir. It sees the qmldir's types and
#                     nothing else -- an unlisted file under services/ simply
#                     does not resolve through `import qs.services`.
#
# Verified with qmllint on a scratch tree, all four cases in one go, which is
# where the last two clauses come from: a relative import of a qmldir-bearing
# directory resolves both a listed and an unlisted sibling, while a bare
# `import m` of the same directory resolves only the listed one and reports
# "Unlisted was not found. Did you mean "Listed"?"
#
# Two inverses are checked as well, both load-fatal:
#
#   qmldir -> no file   A declaration pointing at a file that is not there.
#                       Nothing legitimate produces one.
#   file -> no qmldir   A file under a qmldir directory that no line declares,
#                       reached through a module import. Gated on the module
#                       import, because via a relative import it resolves
#                       anyway and reporting it would be wrong.
#
# `// lint:allow service-missing-import` exempts a file rather than a line --
# this is about a file's import block, not about a line -- and the exemption
# is printed rather than applied silently.
if have python3; then
    echo
    echo "${DIM}service imports${RST}"
    python3 - "$QML_DIR" <<'PY' || fail=1
import os, pathlib, re, sys

root = pathlib.Path(sys.argv[1]).resolve()
# `import qs.<path>` is relative to the folder shell.qml is in (Quickshell's
# "QML Language" guide), which is the only thing that makes that form usable.
shell = next(iter(sorted(root.glob("shell.qml"))), None)
home = shell.parent if shell else root

LINE_COMMENT = re.compile(r"(?<!:)//[^\n]*")
BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
STRING = re.compile(r"\"[^\"\n]*\"|'[^'\n]*'")
# a relative *directory* import, and a module import. The quoted form has to
# be read before strings are blanked, which is why both run against `text`.
RELATIVE = re.compile(r'^\s*import\s+"([^"]+)"\s*$', re.M)
MODULE = re.compile(r"^\s*import\s+([A-Za-z][\w.]*)(?:\s+as\s+[A-Za-z_]\w*)?\s*$", re.M)
# An alias does not change what resolves, so `import qs.services as S` counts
# the same as `import qs.services`; without the alias clause a future file that
# imported that way and then used `Theme` bare would be reported wrongly.
# `singleton Foo 1.0 Foo.qml` or `Foo 1.0 Foo.qml`. The `module X` line is two
# tokens and does not match, and neither do comments or blank lines.
ENTRY = re.compile(r"^(?:singleton\s+)?(\w+)\s+\S+\s+(\S+)$", re.M)
ALLOW = re.compile(r"lint:allow\s+service-missing-import\b")

def hide(pattern, text):
    """blank a match in place, so reported line numbers stay real"""
    return pattern.sub(lambda m: re.sub(r"[^\n]", " ", m.group(0)), text)

# Every directory carrying a qmldir: the `module X` line is the URI it can be
# imported as, and each type line names a file beside it. `declares` is the
# reverse map, type -> the module dirs that declare it.
modules, declares, stems = {}, {}, {}
for q in sorted(root.rglob("qmldir")):
    text = q.read_text()
    mod = re.search(r"^module\s+(\S+)", text, re.M)
    entries = {m.group(1): m.group(2) for m in ENTRY.finditer(text)}
    modules[q.parent] = (mod.group(1) if mod else None, entries)
    for t in entries:
        declares.setdefault(t, set()).add(q.parent)
    for p in q.parent.glob("*.qml"):
        stems.setdefault(p.stem, set()).add(q.parent)
URIS = {v[0]: k for k, v in modules.items() if v[0]}

ALT = "|".join(sorted(declares.keys() | stems.keys(), key=len, reverse=True))
NAME = re.compile(r"(?<![\w.])(%s)\b" % ALT)

errors, allowed = [], []
for d, (_, entries) in sorted(modules.items()):
    for t, src in sorted(entries.items()):
        if not (d / src).is_file():
            errors.append("%s/qmldir declares %s at %s, which does not exist"
                          % (d.relative_to(root.parent), t, src))

for f in sorted(root.rglob("*.qml")):
    raw = f.read_text()
    text = hide(LINE_COMMENT, hide(BLOCK_COMMENT, raw))
    code = hide(STRING, text)
    if ALLOW.search(raw):
        allowed.append(f.relative_to(root.parent))
        continue
    local = {f.parent}
    module = set()
    for p in RELATIVE.findall(text):
        if not p.endswith(".js"):            # a javascript import, not a directory
            local.add((f.parent / p).resolve())
    for u in MODULE.findall(text):
        if u == "qs":
            module.add(home)
        elif u.startswith("qs."):
            module.add((home / u[3:]).resolve())
        elif u in URIS:
            module.add(URIS[u])

    for n, line in enumerate(code.split("\n"), 1):
        for t in sorted(set(NAME.findall(line))):
            where = f.relative_to(root.parent)
            if t in declares:
                if declares[t] & (local | module):
                    continue
                # the copy-pasteable form: this file's own relative path to it
                near = min(declares[t], key=lambda d: len(os.path.relpath(d, f.parent)))
                errors.append('%s:%d  %s needs `import "%s"`'
                              % (where, n, t, os.path.relpath(near, f.parent)))
            elif stems[t] & module:
                errors.append("%s:%d  %s is not declared in %s/qmldir, and a module"
                              " import of it resolves nothing"
                              % (where, n, t, next(iter(stems[t])).relative_to(root.parent)))

for e in errors:
    print("\033[31m    %s\033[0m" % e)
for a in allowed:
    print("\033[33m    %s  exempted by lint:allow service-missing-import\033[0m" % a)
if errors or allowed:
    print("\033[33m  service imports: %d error(s), %d exempted\033[0m" % (len(errors), len(allowed)))
if errors:
    sys.exit(1)
print("\033[32m  every project type the tree names is in scope, and every\033[0m")
print("\033[32m  qmldir entry points at a file that exists\033[0m")
PY
fi

# ------------------------------------------------------------------- qmllint
# `qmllint` on PATH is not necessarily a Qt6 linter. On a machine with both
# the Qt5 and Qt6 devel packages installed, Fedora's alternatives point the
# unversioned name at the Qt5 binary, which reports "qmllint 1.0" and then
# analyses nothing at all: exit 0, zero-byte log, on the entire tree. That
# is the version this script was silently getting, so the "qmllint: clean"
# line below meant far less than it read. Resolve a real Qt6 linter first,
# and treat an empty log as a failure rather than as a pass -- an empty log
# is indistinguishable from never having run the analysis.
QMLLINT=""
for c in qmllint-qt6 /usr/lib64/qt6/bin/qmllint /usr/lib/qt6/bin/qmllint; do
    p="$(command -v "$c" 2>/dev/null || true)"
    if [ -n "$p" ] && [ -x "$p" ]; then QMLLINT="$p"; break; fi
done
if [ -z "$QMLLINT" ]; then
    c="$(command -v qmllint 2>/dev/null || true)"
    # `qmllint --version` prints "qmllint 6.11.2", so the major has to be
    # pulled out rather than matched at the start of the line.
    v="$("$c" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)"
    case "$v" in
        6.*) QMLLINT="$c" ;;
    esac
fi

if [ -n "$QMLLINT" ]; then
    echo
    echo "${DIM}qmllint${RST}  ${DIM}($("$QMLLINT" --version 2>&1))${RST}"
    # shellcheck disable=SC2046
    if ( cd "$QML_DIR" && "$QMLLINT" -I . -I services -I components -I surfaces $(find . -name '*.qml' | sort) ) > /tmp/lint-qmllint.log 2>&1; then
        rc=0
    else
        rc=1
    fi
    if [ ! -s /tmp/lint-qmllint.log ]; then
        # Every real finding in this tree is a warning, so a log with nothing
        # in it means the linter bailed out early -- most often on an import
        # it could not resolve, which is precisely the case that crashes the
        # shell at load and is invisible to the exit code.
        echo "${RED}  qmllint: produced an empty log -- it did not analyse the tree${RST}"
        echo "${YEL}  an unresolvable import makes qmllint exit 0 silently; check imports by hand${RST}"
        fail=1
    elif grep -qE "^Error" /tmp/lint-qmllint.log; then
        # Warnings are not failures here: this tree is not qmllint clean and
        # making it so is a separate job. Errors are.
        #
        # The severity has to be anchored to the start of the line. qmllint
        # echoes the offending source under each diagnostic, so an unanchored
        # "Error" also matches a *warning* whose source merely mentions an
        # error-shaped name -- `FileViewError.FileNotFound` in
        # Notifications.qml:402 is one, and it made this whole tree look like
        # it had a lint error.
        echo "${RED}  qmllint: errors${RST}"
        grep -E "^Error" /tmp/lint-qmllint.log | head -20 | sed 's/^/    /'
        fail=1
    else
        n=$(grep -c "^Warning" /tmp/lint-qmllint.log || true)
        n=${n:-0}
        if [ "$n" -gt 0 ]; then
            echo "${YEL}  qmllint: no errors, $n warning(s) (full log: /tmp/lint-qmllint.log)${RST}"
        else
            echo "${GRN}  qmllint: clean${RST}"
        fi
    fi
    [ "$rc" -ne 0 ] && : # exit status is covered by the branch above
elif have qmllint; then
    echo
    echo "${RED}  qmllint is on PATH but is not a Qt6 linter${RST}"
    echo "${RED}  ($(qmllint --version 2>&1)) - it exits 0 on this tree without analysing it${RST}"
    echo "${YEL}  install qt6-qtdeclarative-devel (gives qmllint-qt6) to get a real check${RST}"
    fail=1
else
    echo "${YEL}  qmllint not found - skipped${RST}"
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "${GRN}lint: clean${RST}"
else
    echo "${RED}lint: FAILED${RST}"
fi
exit "$fail"
