#!/usr/bin/env python3
"""Audit Service.member references against what each singleton exposes.

qmllint already proves every `Foo.bar` in the tree resolves to something, so
a plain missing member cannot survive a clean lint. What qmllint cannot see is
the Round 7 bug class: a function declared inside an IpcHandler is reachable
over `qs ipc call` but is not a method on the singleton, so `Foo.bar()` from
QML does nothing and logs nothing. Notifications.toggleDnd was lost that way
for long enough that it looked like a wiring mistake rather than a scope one.

So this only asks one question: does any reference from QML land on a name
that exists solely at IpcHandler depth?

Exits 0 clean, 1 on a hit, 2 if the parser's self-test fails -- 2 meaning
"do not trust this run", which is deliberately distinct from "found a bug".
"""
import pathlib
import re
import sys
import collections

ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()


def blank(s):
    """Blank comments, string contents and regex literals, preserving
    newlines and offsets so a reported line number is the real one.

    The order of the tests is load-bearing and each one is a trap this
    scanner has already fallen into:

      comments before quotes -- an apostrophe in a line comment
        (`// the adapter's var arrays`) otherwise opens a string that never
        closes, and every brace count after it is wrong.

      regex literals -- `path.replace(/"/g, '\\"')` reads as division
        followed by an unterminated string, blanking the rest of the file.
        A '/' only starts a regex when the previous non-space character
        cannot end an operand, which is what _regex_allowed decides.
    """
    out = list(s)
    i, n = 0, len(s)
    while i < n:
        c = s[i]
        if s.startswith("//", i):
            j = s.find("\n", i)
            for k in range(i, n if j < 0 else j):
                out[k] = " "
            i = n if j < 0 else j
            continue
        if s.startswith("/*", i):
            j = s.find("*/", i + 2)
            for k in range(i, n if j < 0 else j + 2):
                if out[k] != "\n":
                    out[k] = " "
            i = n if j < 0 else j + 2
            continue
        if c in '"\'':
            q = c
            out[i] = " "
            i += 1
            while i < n:
                if s[i] == "\\":
                    out[i] = " "
                    if i + 1 < n:
                        out[i + 1] = " "
                    i += 2
                    continue
                if s[i] == q:
                    out[i] = " "
                    i += 1
                    break
                if s[i] != "\n":
                    out[i] = " "
                i += 1
            continue
        if c == "/" and _regex_allowed(s, i):
            j = _skip_regex(s, i)
            for k in range(i, j):
                out[k] = " "
            i = j
            continue
        i += 1
    return "".join(out)


_REGEX_PREV = set("(,=:[!&|?{};+-*%~^<>\n")


def _regex_allowed(s, i):
    k = i - 1
    while k >= 0 and s[k] in " \t":
        k -= 1
    return k < 0 or s[k] in _REGEX_PREV


def _skip_regex(s, i):
    n = len(s)
    j = i + 1
    in_class = False
    while j < n:
        c = s[j]
        if c == "\\":
            j += 2
            continue
        if c == "\n":
            return i + 1
        if c == "[":
            in_class = True
        elif c == "]":
            in_class = False
        elif c == "/" and not in_class:
            j += 1
            while j < n and s[j].isalpha():
                j += 1
            return j
        j += 1
    return i + 1


DECL = [
    re.compile(r"\s*(?:required\s+)?(?:readonly\s+)?property\s+[\w<>., ]*?\b(\w+)\s*[:=]"),
    re.compile(r"\s*function\s+(\w+)\s*\("),
    re.compile(r"\s*signal\s+(\w+)\s*\("),
    re.compile(r"\s*alias\s+(\w+)\s*:"),
]
ENUM = re.compile(r"\s*enum\s+(\w+)\s*\{")


def parse(path):
    """(singleton-scope names, IpcHandler-only names, enum names).

    Depth is counted per line rather than by walking characters, so a line
    that both opens and closes a brace is attributed to the depth it lives
    at and not the one it leaves behind. Getting that backwards makes every
    singleton member look nested, which is the failure that produced 69
    phantom problems on the first run of this script.
    """
    src = blank(path.read_text())
    lines = src.split("\n")

    start_depth = []
    d = 0
    for ln in lines:
        start_depth.append(d)
        d += ln.count("{") - ln.count("}")
    if d != 0:
        raise ValueError(f"{path.name}: unbalanced after blanking (depth {d})")

    ipc_depths = {
        start_depth[i] + 1
        for i, ln in enumerate(lines)
        if re.match(r"\s*IpcHandler\s*\{", ln)
    }

    exposed, ipc_only = set(), set()
    for i, ln in enumerate(lines):
        name = None
        for rx in DECL:
            m = rx.match(ln)
            if m:
                name = m.group(1)
                break
        if name is None:
            continue
        if start_depth[i] in ipc_depths:
            ipc_only.add(name)
        elif start_depth[i] <= 1:
            exposed.add(name)

    enums = {m.group(1) for ln in lines if (m := ENUM.match(ln))}
    return exposed, ipc_only, enums


def main():
    svc_dir = ROOT / "services"
    qml_dir = svc_dir / "qmldir"
    if not qml_dir.is_file():
        print(f"  no services/qmldir under {ROOT}")
        return 2

    services = {}
    for ln in qml_dir.read_text().split("\n"):
        m = re.match(r"singleton\s+(\w+)\s+\S+\s+(\S+)", ln)
        if m:
            services[m.group(1)] = svc_dir / m.group(2)

    info = {}
    for name, path in services.items():
        try:
            info[name] = parse(path)
        except ValueError as e:
            print(f"  PARSER FAILED: {e}")
            return 2

    # Self-test. These members are known to sit on their singletons, and
    # several are referenced from surfaces that demonstrably work. If the
    # parser cannot see them, it is the parser that is wrong and this run
    # reports nothing -- better a loud non-answer than a confident wrong one.
    probe = [
        ("Volume", "setVolume"), ("Brightness", "setBrightness"),
        ("Notifications", "dismiss"),
        ("Media", "togglePlay"),
        ("Theme", "colors"), ("ControlCenterLayout", "catalogue"),
    ]
    broken = [f"{s}.{m}" for s, m in probe if m not in info[s][0]]
    if broken:
        print("  PARSER SELF-TEST FAILED, nothing reported:")
        for x in broken:
            print(f"    {x}")
        return 2

    refs = collections.defaultdict(set)
    sites = collections.defaultdict(list)
    files = sorted(p for p in ROOT.rglob("*.qml"))
    for p in files:
        src = blank(p.read_text())
        for m in re.finditer(r"\b([A-Z]\w+)\.(\w+)", src):
            s, mem = m.group(1), m.group(2)
            if s in services:
                refs[s].add(mem)
                sites[(s, mem)].append(
                    f"{p.relative_to(ROOT)}:{src[:m.start()].count(chr(10)) + 1}")

    problems = []
    for s, mems in sorted(refs.items()):
        exposed, ipc_only, enums = info[s]
        for mem in sorted(mems):
            if mem in exposed or mem in enums:
                continue
            if mem in ipc_only:
                problems.append((s, mem, sites[(s, mem)]))

    if problems:
        for s, mem, where in problems:
            print(f"  IPC-ONLY  {s}.{mem}()")
            for w in where[:4]:
                print(f"             {w}")
            print(f"             declared only inside an IpcHandler -- reachable over")
            print(f"             `qs ipc call', but {s}.{mem}() from QML is undefined.")
    else:
        print("  clean: no QML reference resolves to an IpcHandler-only member")

    total = sum(len(v) for v in refs.values())
    print(f"  {len(services)} singletons, {len(files)} files, {total} references, "
          f"{len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
