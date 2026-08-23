#!/usr/bin/env bash
# Single-pass .desktop entry listing for the launcher. Deliberately simple:
# no locale-aware Name[xx]=, no icon theme resolution, no de-duplication
# across multiple XDG data dirs by app-id. This is a known, documented
# simplification -- fine for a first working launcher, worth revisiting with
# a proper XDG desktop-entry parser (or reusing an existing one, e.g.
# `fuzzel --list` / `wofi --show drun`'s internals) before relying on it daily.
#
# Output: one line per app, tab-separated: Name<TAB>Comment<TAB>Exec<TAB>Icon
set -euo pipefail

search_dirs=(
    "$HOME/.local/share/applications"
    "/usr/share/applications"
    "/usr/local/share/applications"
)

for dir in "${search_dirs[@]}"; do
    [[ -d "$dir" ]] || continue
    for entry in "$dir"/*.desktop; do
        [[ -f "$entry" ]] || continue

        # skip entries explicitly hidden from menus
        grep -q '^NoDisplay=true' "$entry" 2>/dev/null && continue

        name="$(grep -m1 '^Name=' "$entry" | cut -d= -f2-)"
        comment="$(grep -m1 '^Comment=' "$entry" | cut -d= -f2-)"
        exec_line="$(grep -m1 '^Exec=' "$entry" | cut -d= -f2-)"
        icon="$(grep -m1 '^Icon=' "$entry" | cut -d= -f2-)"

        [[ -z "$name" || -z "$exec_line" ]] && continue

        printf '%s\t%s\t%s\t%s\n' "$name" "$comment" "$exec_line" "$icon"
    done
done | sort -u
