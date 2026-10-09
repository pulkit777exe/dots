#!/usr/bin/env python3

import configparser
import json
import os
import re
import sys

FIELD_CODE_RE = re.compile(r"%[fFuUick]")

def search_dirs():
    xdg_data_home = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
    xdg_data_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share")
    dirs = [xdg_data_home] + xdg_data_dirs.split(":")
    return [os.path.join(d, "applications") for d in reversed(dirs)]

def clean_exec(raw_exec):
    if not raw_exec:
        return ""
    return FIELD_CODE_RE.sub("", raw_exec).strip()

def load_entry(path):
    parser = configparser.RawConfigParser(strict=False)
    try:
        parser.read(path, encoding="utf-8")
    except Exception:
        return None
    if not parser.has_section("Desktop Entry"):
        return None
    section = parser["Desktop Entry"]

    if section.get("Type", "Application") != "Application":
        return None
    if section.getboolean("NoDisplay", fallback=False):
        return None
    if section.getboolean("Hidden", fallback=False):
        return None

    name = section.get("Name", "")
    raw_exec = section.get("Exec", "")
    if not name or not raw_exec:
        return None

    categories = [c for c in section.get("Categories", "").split(";") if c]

    return {
        "name": name,
        "exec": clean_exec(raw_exec),
        "icon": section.get("Icon", ""),
        "description": section.get("Comment", ""),
        "terminal": section.getboolean("Terminal", fallback=False),
        "categories": categories,
    }

def main():
    entries = {}
    for d in search_dirs():
        if not os.path.isdir(d):
            continue
        try:
            names = sorted(os.listdir(d))
        except OSError:
            continue
        for fname in names:
            if not fname.endswith(".desktop"):
                continue
            entry = load_entry(os.path.join(d, fname))
            if entry:
                entries[fname] = entry

    result = sorted(entries.values(), key=lambda e: e["name"].lower())
    json.dump(result, sys.stdout)

if __name__ == "__main__":
    main()
