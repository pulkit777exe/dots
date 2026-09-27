#!/usr/bin/env python3
"""
iris-generate-themes.py — generate themes/<theme>/themes.json from iris at startup.

For each theme directory in <shellDir>/themes/<theme_name>/,
find a representative wallpaper (first discovered image),
run harman1307/iris to generate palette, remap to Theme schema,
and write themes/<theme>/themes.json with { "name": "...", "colors": {...} }.

No hardcoded wallpaper names — discovers via filesystem.
No hardcoded colors — from iris.
"""
import json
import os
import pathlib
import subprocess
import sys

script_dir = pathlib.Path(__file__).resolve().parent
shell_dir = script_dir.parent
if "QUICKSHELL_SHELL_DIR" in os.environ:
    shell_dir = pathlib.Path(os.environ["QUICKSHELL_SHELL_DIR"])
themes_root = shell_dir / "themes"

# Fallback colors if iris fails
FALLBACK = {
    "background": "#202020", "surface": "#282828", "surfaceAlt": "#303030",
    "border": "#404040", "text": "#f0f0f0", "textMuted": "#b0b0b0",
    "accent": "#88c0d0", "accentText": "#202020",
    "danger": "#e06060", "warning": "#e0c060", "success": "#60c080"
}

def find_iris():
    candidates = [
        pathlib.Path.home() / ".local/bin/iris",
        pathlib.Path("/usr/local/bin/iris"),
    ]
    for p in candidates:
        if p.is_file() and os.access(p, os.X_OK):
            return str(p)
    # fallback to PATH
    for d in os.environ.get("PATH", "").split(":"):
        p = pathlib.Path(d) / "iris"
        if p.is_file() and os.access(p, os.X_OK):
            return str(p)
    return None

def hex_to_rgb(hex):
    h = hex.lstrip("#")
    if len(h) == 3:
        h = "".join(c*2 for c in h)
    num = int(h, 16)
    return (num >> 16) & 255, (num >> 8) & 255, num & 255

def hex_lightness(hex):
    r, g, b = hex_to_rgb(hex)
    r /= 255; g /= 255; b /= 255
    return (max(r, g, b) + min(r, g, b)) / 2

def to_hex(r, g, b):
    return "#{:02x}{:02x}{:02x}".format(max(0, min(255, round(r))), max(0, min(255, round(g))), max(0, min(255, round(b))))

def shift_further(hexA, hexB, amount):
    ar, ag, ab = hex_to_rgb(hexA)
    br, bg, bb = hex_to_rgb(hexB)
    return to_hex(br + (br - ar) * amount, bg + (bg - ag) * amount, bb + (bb - ab) * amount)

def with_alpha(hex, alpha01):
    a = max(0, min(255, round(alpha01 * 255)))
    return "#{:02x}{}".format(a, hex.lstrip("#"))

def luminance(hex):
    r, g, b = hex_to_rgb(hex)
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255

def remap_iris(p):
    surface = p.get("surface") or p.get("bg")
    return {
        "background": p["bg"],
        "surface": surface,
        "surfaceAlt": shift_further(p["bg"], surface, 1.0),
        "border": with_alpha(p["fg"], 0.12),
        "text": p["fg"],
        "textMuted": p.get("dim") or p["fg"],
        "accent": p["accent"],
        "accentText": "#101010" if luminance(p["accent"]) > 0.5 else "#f5f5f5",
        "danger": p.get("red") or "#e06060",
        "warning": p.get("yellow") or "#e0c060",
        "success": p.get("green") or "#60c080"
    }

def discover_wallpapers(theme_path):
    exts = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}
    wallpapers = []
    for root, dirs, files in os.walk(theme_path):
        for f in sorted(files):
            if pathlib.Path(f).suffix.lower() in exts:
                wallpapers.append(pathlib.Path(root) / f)
    return sorted(wallpapers)

def run_iris(iris_bin, wallpaper_path):
    # Try dark=auto first? iris --dark -1 for auto, else try 1
    # We'll probe lightness of previous fallback or just use auto
    # Use --dark 1 for dark themes, 0 for light - we autodetect via iris --dark -1 if available
    # For compatibility, try -1 first, fallback to 1
    for dark in ["-1", "1", "0"]:
        try:
            result = subprocess.run([iris_bin, str(wallpaper_path), "--json-only", "--dark", dark],
                                    capture_output=True, text=True, timeout=5)
            if result.returncode == 0 and result.stdout.strip():
                try:
                    pal = json.loads(result.stdout)
                    if "bg" in pal and "fg" in pal and "accent" in pal:
                        return pal
                except:
                    continue
        except Exception as e:
            continue
    return None

def main():
    iris_bin = find_iris()
    if not iris_bin:
        print("iris not found, skipping generation", file=sys.stderr)
        return 0
    if not themes_root.is_dir():
        print(f"themes root not found: {themes_root}", file=sys.stderr)
        return 1

    for entry in sorted(themes_root.iterdir()):
        if not entry.is_dir() or entry.name.startswith(".") or entry.name == "themes.json":
            continue
        key = entry.name
        wallpapers = discover_wallpapers(entry)
        if not wallpapers:
            print(f"skip {key}: no wallpapers", file=sys.stderr)
            continue
        # Pick first wallpaper by sorted order (deterministic, not hardcoded name)
        wallpaper = wallpapers[0]
        print(f"generating {key} from {wallpaper} via {iris_bin}...", file=sys.stderr)
        palette = run_iris(iris_bin, wallpaper)
        if not palette:
            print(f"  iris failed for {key}, using fallback", file=sys.stderr)
            colors = FALLBACK
        else:
            try:
                colors = remap_iris(palette)
            except Exception as e:
                print(f"  remap failed for {key}: {e}", file=sys.stderr)
                colors = FALLBACK

        # Load existing themes.json if present to keep name
        theme_json_path = entry / "themes.json"
        existing = {}
        if theme_json_path.is_file():
            try:
                with open(theme_json_path, "r", encoding="utf-8") as f:
                    existing = json.load(f)
            except:
                existing = {}

        # Preserve human name if exists, else capitalize key
        name = existing.get("name") or key.capitalize()
        # Special pretty names
        pretty_map = {
            "catppuccin": "Catppuccin",
            "everforest": "Everforest",
            "gruvbox": "Gruvbox",
            "ariadne": "Ariadne",
            "monochrome": "Monochrome",
            "horizon": "Horizon",
        }
        if key in pretty_map:
            name = pretty_map[key]

        out = {"name": name, "colors": colors}
        # Write atomically
        tmp = theme_json_path.with_suffix(".tmp")
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(out, f, indent=2)
        tmp.replace(theme_json_path)
        print(f"  wrote {theme_json_path}", file=sys.stderr)

    print("done", file=sys.stderr)
    return 0

if __name__ == "__main__":
    sys.exit(main())
