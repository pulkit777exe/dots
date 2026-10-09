#!/usr/bin/env python3
"""Discover palettes from ~/.config/colors — never from the Quickshell tree.

index.json maps palette keys to wallpaper directories (usually outside
this repo) and names the active palette (`current`, seeded from `default`).
Per-palette colors/themes/<key>/colors.json is the hand-authored static
palette — the single source of truth for both the shell and the desktop.
"""
import json
import os
import sys
import pathlib

HOME = pathlib.Path.home()
CONFIG = pathlib.Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
COLORS_ROOT = CONFIG / "colors"
INDEX = COLORS_ROOT / "index.json"

KNOWN_DIRS = {
    "ariadne": ["aridane", "ariadne"],
    "catppuccin": ["catpuccin", "catpuccin"],
    "everforest": ["everforest"],
    "gruvbox": ["gruvbox"],
    "horizon": ["horizon"],
    "monochrome": ["monochrome"],
}

EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}
DEFAULT_THEME = "ariadne"


def discover_images(root: pathlib.Path):
    if not root.is_dir():
        return []
    out = []
    for dirpath, _, files in os.walk(root):
        for f in sorted(files):
            if pathlib.Path(f).suffix.lower() in EXTS:
                out.append(str((pathlib.Path(dirpath) / f).resolve()))
    return sorted(out)


def load_colors(theme_key: str):
    """The palette exactly as authored; no invented colours here.

    A missing or broken colors.json yields an empty set — the shell's
    own pre-discovery defaults cover that, and the tests enforce that
    the real palettes are complete.
    """
    p = COLORS_ROOT / "themes" / theme_key / "colors.json"
    if p.is_file():
        try:
            data = json.loads(p.read_text())
            return {k: v for k, v in data.items() if isinstance(v, str)}
        except Exception:
            pass
    return {}


def guess_wallpaper_dir(key: str) -> pathlib.Path | None:
    names = KNOWN_DIRS.get(key, [key])
    candidates = []
    for name in names:
        candidates.extend([
            HOME / "Downloads" / name,
            HOME / "Pictures" / "Wallpapers" / name,
            HOME / "Pictures" / name,
            HOME / "wallpapers" / name,
            COLORS_ROOT / "themes" / key / "wallpapers",
            COLORS_ROOT / "themes" / key,
        ])
    for c in candidates:
        if c.is_dir() and discover_images(c):
            return c
    return None


def ensure_index():
    COLORS_ROOT.mkdir(parents=True, exist_ok=True)
    themes = {}
    raw = {}
    if INDEX.is_file():
        try:
            data = json.loads(INDEX.read_text())
            raw = data.get("themes", {})
            # `themes` has been written in two shapes over time. The catalog
            # format is a dict of key -> metadata, but older checkouts (and
            # anything hand-edited) shipped a bare list of theme keys, which
            # used to blow up here with AttributeError: 'list' object has no
            # attribute 'get' and took the whole discovery process down.
            # Normalize instead of assuming.
            if isinstance(raw, list):
                themes = {str(k): {} for k in raw}
            elif isinstance(raw, dict):
                themes = {str(k): (dict(v) if isinstance(v, dict) else {}) for k, v in raw.items()}
            default = data.get("default") or data.get("current")
        except Exception:
            data, default = {}, None
    else:
        data, default = {}, None

    changed = False
    for key in KNOWN_DIRS:
        entry = themes.get(key, {})
        wdir = entry.get("wallpaperDir")
        if not wdir or not pathlib.Path(wdir).is_dir():
            guessed = guess_wallpaper_dir(key)
            if guessed:
                entry["wallpaperDir"] = str(guessed)
                changed = True
        entry.setdefault("name", key)
        themes[key] = entry
        if default is None:
            default = key

    # Preserve any extra top-level keys the index carries (scheme/accent/etc.)
    # instead of clobbering the whole file. `current` is the declarative
    # active-theme knob and is kept as-is once set — only seeded from
    # `default` when absent — so editing index.json is a supported way to
    # change the active theme. (`default` stays what a fresh install picks.)
    out = dict(data) if isinstance(data, dict) else {}
    out["default"] = default or DEFAULT_THEME
    out["current"] = out.get("current") or out["default"]
    out["themes"] = themes

    if changed or not INDEX.is_file() or isinstance(raw, list):
        INDEX.write_text(json.dumps(out, indent=2) + "\n")
    return {"default": out["default"], "current": out["current"], "themes": themes}


def main():
    idx = ensure_index()
    themes = {}
    default = idx.get("default")
    current = idx.get("current") or default
    for key, meta in idx.get("themes", {}).items():
        name = meta.get("name", key)
        wdir = pathlib.Path(meta.get("wallpaperDir", ""))
        extra = [pathlib.Path(p) for p in meta.get("wallpaperDirs", [])]
        walls = discover_images(wdir) if wdir else []
        for d in extra:
            walls.extend(discover_images(d))
        # unique preserve order
        seen = set()
        unique = []
        for w in walls:
            if w not in seen:
                seen.add(w)
                unique.append(w)
        themes[key] = {
            "name": name,
            "wallpaperDir": str(wdir) if wdir else "",
            "wallpapers": unique,
            "colors": load_colors(key),
        }
    # Validate the named themes *after* the loop. While these checks sat
    # inside it, `themes` was still missing the key being tested, so
    # `default` (and `current`) always collapsed to the first theme key
    # rather than the one index.json actually named.
    if default not in themes:
        default = next(iter(themes), DEFAULT_THEME)
    if current not in themes:
        current = default
    json.dump(
        {"default": default, "current": current, "themes": themes},
        sys.stdout,
        indent=2,
    )
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
