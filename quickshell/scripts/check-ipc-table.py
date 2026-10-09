#!/usr/bin/env python3

import pathlib
import re
import subprocess
import sys

DOC = pathlib.Path(__file__).resolve().parent.parent / "ARCHITECTURE.md"
HEADING = "## Complete IPC reference"
TRAILER = "A recurring bug class worth knowing"

def parse_table():
    doc = DOC.read_text()
    if HEADING not in doc or TRAILER not in doc:
        raise ValueError(f"cannot find the IPC table in {DOC}")
    sec = doc[doc.index(HEADING):doc.index(TRAILER)]
    claimed = {}
    for line in sec.split("\n"):
        if not line.startswith("| `") or "Target" in line:
            continue
        parts = [p.strip() for p in line.strip("|").split("|")]
        if len(parts) < 2:
            continue
        target = parts[0].strip("`")
        fns = re.findall(r"`([A-Za-z_][A-Za-z0-9_]*)", parts[1])
        if fns:
            claimed.setdefault(target, set()).update(fns)
    return claimed

def parse_shell():
    out = subprocess.run(["quickshell", "ipc", "show"],
                         capture_output=True, text=True)
    if out.returncode != 0 or "target " not in out.stdout:
        return None
    real, cur = {}, None
    for line in out.stdout.split("\n"):
        m = re.match(r"^target (\S+)", line)
        if m:
            cur = m.group(1)
            real[cur] = set()
            continue
        m = re.match(r"^\s+function (\w+)", line)
        if m and cur:
            real[cur].add(m.group(1))
    return real

def main():
    try:
        claimed = parse_table()
    except (OSError, ValueError) as e:
        print(f"  {e}", file=sys.stderr)
        return 2

    real = parse_shell()
    if real is None:
        print("  no running quickshell instance", file=sys.stderr)
        return 2

    problems = []
    for target in sorted(set(claimed) | set(real)):
        c, r = claimed.get(target, set()), real.get(target, set())
        if c == r:
            continue
        if c - r:
            problems.append(
                f"{target}: documented but not callable: "
                + " ".join(sorted(c - r)))
        if r - c:
            problems.append(
                f"{target}: callable but undocumented: "
                + " ".join(sorted(r - c)))

    if problems:
        for p in problems:
            print("  " + p, file=sys.stderr)
        return 1

    total = sum(len(v) for v in real.values())
    print(f"{total} functions across {len(real)} targets")
    return 0

if __name__ == "__main__":
    sys.exit(main())
