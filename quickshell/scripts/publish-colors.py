#!/usr/bin/env python3
"""Publish Iris palettes into ~/.config/colors for the whole desktop.

Iris remains the generator (~/.cache/iris). This script is the shared
desktop layer: semantic colors + live apply for Hyprland/Kitty/GTK.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
COLORS_DIR = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "colors"
IRIS_CACHE = HOME / ".cache" / "iris"
FALLBACK = {
    "background": "#202020",
    "surface": "#282828",
    "surfaceAlt": "#303030",
    "surfaceElevated": "#383838",
    "surfaceMuted": "#b0282828",
    "border": "#1a404040",
    "divider": "#12404040",
    "foreground": "#f0f0f0",
    "muted": "#b0b0b0",
    "accent": "#88c0d0",
    "accentVariant": "#6aa8b8",
    "accentText": "#202020",
    "error": "#e06060",
    "warning": "#e0c060",
    "success": "#60c080",
    # aliases used by existing QML
    "text": "#f0f0f0",
    "textMuted": "#b0b0b0",
    "danger": "#e06060",
}


def hex_to_rgb(h: str):
    h = h.lstrip("#")
    if len(h) == 8:
        h = h[2:]
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    n = int(h, 16)
    return (n >> 16) & 255, (n >> 8) & 255, n & 255


def to_hex(r, g, b):
    clamp = lambda v: max(0, min(255, round(v)))
    return f"#{clamp(r):02x}{clamp(g):02x}{clamp(b):02x}"


def hex_lightness(h: str) -> float:
    r, g, b = hex_to_rgb(h)
    r, g, b = r / 255, g / 255, b / 255
    return (max(r, g, b) + min(r, g, b)) / 2


def hex_sat(h: str) -> float:
    r, g, b = [x / 255 for x in hex_to_rgb(h)]
    mx, mn = max(r, g, b), min(r, g, b)
    if mx == mn:
        return 0
    l = (mx + mn) / 2
    return (mx - mn) / (1 - abs(2 * l - 1))


def darken(h: str, factor: float) -> str:
    r, g, b = hex_to_rgb(h)
    f = max(0, min(1, factor))
    return to_hex(r * (1 - f), g * (1 - f), b * (1 - f))


def shift_further(a: str, b: str, amount: float) -> str:
    ar, ag, ab = hex_to_rgb(a)
    br, bg, bb = hex_to_rgb(b)
    return to_hex(br + (br - ar) * amount, bg + (bg - ag) * amount, bb + (bb - ab) * amount)


def with_alpha(h: str, a: float) -> str:
    hx = h.lstrip("#")
    if len(hx) == 8:
        hx = hx[2:]
    alpha = max(0, min(255, round(a * 255)))
    return f"#{alpha:02x}{hx}"


def luminance(h: str) -> float:
    r, g, b = hex_to_rgb(h)
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255


def remap_iris(p: dict) -> dict:
    surface = p.get("surface") or p.get("bg")
    bg = p.get("bg", FALLBACK["background"])
    surf = surface or FALLBACK["surface"]
    if hex_lightness(bg) > 0.28:
        bg = darken(bg, 0.22)
    elif hex_lightness(bg) > 0.22:
        bg = darken(bg, 0.10)
    if hex_lightness(surf) > 0.32:
        surf = darken(surf, 0.18)

    accent = p.get("accent", FALLBACK["accent"])
    is_mono = hex_sat(accent) < 0.15 and hex_sat(bg) < 0.12
    if is_mono:
        bg, surf, accent = "#111111", "#1c1c1c", "#c8c8c8"

    surf_alt = shift_further(bg, surf, 1.0)
    fg = p.get("fg", FALLBACK["foreground"])
    dim = p.get("dim", fg)
    danger = p.get("red", FALLBACK["error"])
    warning = p.get("yellow", FALLBACK["warning"])
    success = p.get("green", FALLBACK["success"])
    accent_text = "#101010" if luminance(accent) > 0.5 else "#f5f5f5"
    return {
        "background": bg,
        "surface": surf,
        "surfaceAlt": surf_alt,
        "surfaceElevated": shift_further(surf, surf_alt, 0.8),
        "surfaceMuted": with_alpha(surf, 0.7),
        "border": with_alpha(fg, 0.10),
        "divider": with_alpha(fg, 0.07),
        "foreground": fg,
        "muted": dim,
        "accent": accent,
        "accentVariant": shift_further(bg, accent, 0.65),
        "accentText": accent_text,
        "error": danger,
        "warning": warning,
        "success": success,
        "text": fg,
        "textMuted": dim,
        "danger": danger,
        "iris": {
            "bg": p.get("bg"),
            "fg": p.get("fg"),
            "surface": p.get("surface"),
            "dim": p.get("dim"),
            "accent": p.get("accent"),
            "red": p.get("red"),
            "green": p.get("green"),
            "yellow": p.get("yellow"),
        },
    }


def write_css(path: Path, colors: dict):
    lines = [":root {\n"]
    for k, v in colors.items():
        if isinstance(v, str) and v.startswith("#"):
            lines.append(f"  --{k}: {v};\n")
            lines.append(f"  --color-{k}: {v};\n")
    lines.append("}\n")
    path.write_text("".join(lines))


def write_sh(path: Path, colors: dict):
    lines = []
    for k, v in colors.items():
        if isinstance(v, str) and v.startswith("#"):
            lines.append(f'{k}="{v}"\n')
    path.write_text("".join(lines))


def write_hypr(path: Path, colors: dict):
    acc = colors["accent"].lstrip("#")
    surf = colors["surface"].lstrip("#")
    if len(acc) == 8:
        acc = acc[2:]
    if len(surf) == 8:
        surf = surf[2:]
    path.write_text(
        f"$bg = rgb({colors['background'].lstrip('#')})\n"
        f"$fg = rgb({colors['foreground'].lstrip('#')})\n"
        f"$accent = rgb({acc})\n"
        f"$surface = rgb({surf})\n"
        f"$red = rgb({colors['error'].lstrip('#')})\n"
        f"$green = rgb({colors['success'].lstrip('#')})\n"
        f"$yellow = rgb({colors['warning'].lstrip('#')})\n"
        f"\n"
        f"general {{\n"
        f"    col.active_border = rgba({acc}ff)\n"
        f"    col.inactive_border = rgba({surf}aa)\n"
        f"}}\n"
    )


def write_kitty(path: Path, colors: dict, iris: dict | None):
    bg = colors["background"]
    fg = colors["foreground"]
    acc = colors["accent"]
    lines = [
        f"foreground {fg}\n",
        f"background {bg}\n",
        f"cursor {acc}\n",
        f"selection_background {colors['surfaceAlt']}\n",
        f"selection_foreground {fg}\n",
        f"color0 {bg}\n",
        f"color1 {colors['error']}\n",
        f"color2 {colors['success']}\n",
        f"color3 {colors['warning']}\n",
        f"color4 {acc}\n",
        f"color5 {acc}\n",
        f"color6 {colors['accentVariant']}\n",
        f"color7 {fg}\n",
        f"color8 {colors['surface']}\n",
        f"color9 {colors['error']}\n",
        f"color10 {colors['success']}\n",
        f"color11 {colors['warning']}\n",
        f"color12 {acc}\n",
        f"color13 {acc}\n",
        f"color14 {colors['accentVariant']}\n",
        f"color15 {fg}\n",
        f"active_border_color {acc}\n",
        f"inactive_border_color {colors['surface']}\n",
        f"url_color {acc}\n",
    ]
    path.write_text("".join(lines))


def write_gtk(path: Path, colors: dict):
    path.write_text(
        f"@define-color theme_bg_color {colors['background']};\n"
        f"@define-color theme_fg_color {colors['foreground']};\n"
        f"@define-color theme_selected_bg_color {colors['accent']};\n"
        f"@define-color theme_selected_fg_color {colors['accentText']};\n"
        f"@define-color borders {colors['surfaceAlt']};\n"
    )


def run(cmd: list[str]) -> None:
    try:
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4)
    except Exception:
        pass


def ensure_gtk_import(gtk_css_path: Path) -> None:
    """Make sure gtk-N.0/gtk.css @imports colors.css.

    GTK only ever reads gtk.css itself — writing colors.css (as
    apply_live already did) has no effect on its own, since nothing
    was importing it. This adds the import once, idempotently, and
    otherwise leaves the file alone so any of the user's own gtk.css
    customizations survive.
    """
    marker = '@import url("colors.css");'
    gtk_css_path.parent.mkdir(parents=True, exist_ok=True)
    existing = gtk_css_path.read_text() if gtk_css_path.is_file() else ""
    if marker in existing:
        return
    gtk_css_path.write_text(marker + "\n" + existing)


def apply_live(colors: dict, kitty_path: Path) -> None:
    acc = colors["accent"].lstrip("#")
    surf = colors["surface"].lstrip("#")
    if len(acc) == 8:
        acc = acc[2:]
    if len(surf) == 8:
        surf = surf[2:]
    run(["hyprctl", "keyword", "general:col.active_border", f"rgba({acc}ff)"])
    run(["hyprctl", "keyword", "general:col.inactive_border", f"rgba({surf}aa)"])
    run(["kitty", "@", "set-colors", "--all", "--configured", str(kitty_path)])

    gtk3_dir = HOME / ".config" / "gtk-3.0"
    gtk4_dir = HOME / ".config" / "gtk-4.0"
    write_gtk(gtk3_dir / "colors.css", colors)
    write_gtk(gtk4_dir / "colors.css", colors)
    ensure_gtk_import(gtk3_dir / "gtk.css")
    ensure_gtk_import(gtk4_dir / "gtk.css")

    # The color-scheme signal is what actually matters for most GTK3/
    # GTK4/libadwaita apps in practice — the @define-color overrides
    # above only take effect on apps using an older, non-libadwaita
    # GTK3 theme that references theme_bg_color/theme_selected_bg_color
    # by name. A libadwaita app picks its own dark/light palette from
    # this setting and largely ignores arbitrary accent hex values
    # (GNOME's own accent-color setting is a fixed named palette, not
    # arbitrary hex, so we don't attempt to force it here).
    is_dark = hex_lightness(colors["background"]) < 0.5
    run([
        "gsettings", "set", "org.gnome.desktop.interface",
        "color-scheme", "prefer-dark" if is_dark else "default",
    ])


def load_iris_palette(src: Path | None) -> dict:
    if src and src.is_file():
        return json.loads(src.read_text())
    cache = IRIS_CACHE / "colors.json"
    if cache.is_file():
        return json.loads(cache.read_text())
    raise FileNotFoundError("no iris palette found")


def is_already_semantic(palette: dict) -> bool:
    """True if `palette` is already remap_iris()'s output shape (a
    preset theme's own colors/themes/<name>/colors.json snapshot)
    rather than a raw Iris palette (bg/fg/surface/accent/...). Lets
    main() publish a preset theme directly without corrupting it by
    running it back through remap_iris(), which expects the raw shape
    and would silently fall back to FALLBACK for every key a semantic
    palette doesn't have under those raw names."""
    return "background" in palette and "accentText" in palette


def main():
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    theme_name = sys.argv[2] if len(sys.argv) > 2 else None
    palette = load_iris_palette(src)
    COLORS_DIR.mkdir(parents=True, exist_ok=True)
    colors = palette if is_already_semantic(palette) else remap_iris(palette)

    (COLORS_DIR / "current.json").write_text(json.dumps(colors, indent=2))
    write_css(COLORS_DIR / "colors.css", colors)
    write_sh(COLORS_DIR / "colors.sh", colors)
    write_hypr(COLORS_DIR / "hyprland.conf", colors)
    write_kitty(COLORS_DIR / "kitty.conf", colors, palette)
    write_gtk(COLORS_DIR / "gtk.css", colors)

    if theme_name:
        snap = COLORS_DIR / "themes" / theme_name
        snap.mkdir(parents=True, exist_ok=True)
        (snap / "colors.json").write_text(json.dumps(colors, indent=2))

    # Keep kitty include in sync
    kitty_include = HOME / ".config" / "kitty" / "current-theme.conf"
    shutil.copyfile(COLORS_DIR / "kitty.conf", kitty_include)

    apply_live(colors, COLORS_DIR / "kitty.conf")
    print(json.dumps({"ok": True, "theme": theme_name, "accent": colors["accent"]}))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(json.dumps({"ok": False, "error": str(e)}), file=sys.stderr)
        sys.exit(1)
