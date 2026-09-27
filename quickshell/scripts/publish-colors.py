#!/usr/bin/env python3
"""Publish a theme's static palette into ~/.config/colors for the whole desktop.

The palette is hand-authored and lives at
~/.config/colors/themes/<name>/colors.json — there is no generator and no
sampling. This script is the shared desktop layer: it copies that palette
out to the files Hyprland/GTK/CSS consumers read, and pushes the border
colours live.

Active theme resolution, highest priority first:
  1. CLI argument:      publish-colors.py <theme>
  2. $QUICKSHELL_THEME
  3. `current` in ~/.config/colors/index.json (falls back to `default`)
  4. "everforest"
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
COLORS_DIR = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "colors"
INDEX_JSON = COLORS_DIR / "index.json"
THEME_ENV = "QUICKSHELL_THEME"
DEFAULT_THEME = "everforest"
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


def hex_lightness(h: str) -> float:
    r, g, b = hex_to_rgb(h)
    r, g, b = r / 255, g / 255, b / 255
    return (max(r, g, b) + min(r, g, b)) / 2


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


def write_kitty(path: Path, colors: dict):
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


def apply_live(colors: dict) -> None:
    """Push the palette to things already running.

    Hyprland's border colours are updated live. Kitty is deliberately NOT
    pushed to: the terminal stays on its own defaults, so a theme switch
    must not repaint it.
    """
    acc = colors["accent"].lstrip("#")
    surf = colors["surface"].lstrip("#")
    if len(acc) == 8:
        acc = acc[2:]
    if len(surf) == 8:
        surf = surf[2:]
    run(["hyprctl", "keyword", "general:col.active_border", f"rgba({acc}ff)"])
    run(["hyprctl", "keyword", "general:col.inactive_border", f"rgba({surf}aa)"])

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


def resolve_theme(cli_theme: str | None) -> str:
    """Which theme to publish. CLI beats env beats index.json beats default."""
    if cli_theme:
        return cli_theme
    env = os.environ.get(THEME_ENV)
    if env:
        return env
    if INDEX_JSON.is_file():
        try:
            data = json.loads(INDEX_JSON.read_text())
            named = data.get("current") or data.get("default")
            if named:
                return str(named)
        except Exception:
            pass
    return DEFAULT_THEME


def load_theme_palette(theme: str) -> dict:
    """Read a theme's own hand-authored colors.json.

    Missing keys are filled from FALLBACK (same defaulting list-themes.py
    applies) so a partially hand-edited palette can't break the writers
    below or leave current.json out of step with what the shell renders.
    """
    path = COLORS_DIR / "themes" / theme / "colors.json"
    if not path.is_file():
        raise FileNotFoundError(f"no colors.json for theme {theme!r} ({path})")
    palette = json.loads(path.read_text())
    if not isinstance(palette, dict):
        raise ValueError(f"{path} is not a color palette object")
    colors = {k: v for k, v in palette.items() if isinstance(v, str)}
    for k, v in FALLBACK.items():
        colors.setdefault(k, v)
    return colors


def main():
    theme = resolve_theme(sys.argv[1] if len(sys.argv) > 1 else None)
    colors = load_theme_palette(theme)
    COLORS_DIR.mkdir(parents=True, exist_ok=True)

    (COLORS_DIR / "current.json").write_text(json.dumps(colors, indent=2))
    write_css(COLORS_DIR / "colors.css", colors)
    write_sh(COLORS_DIR / "colors.sh", colors)
    write_hypr(COLORS_DIR / "hyprland.conf", colors)
    write_gtk(COLORS_DIR / "gtk.css", colors)
    # Record the palette, but do not theme the terminal: kitty.conf does not
    # include this file, and apply_live() does not push set-colors. The
    # terminal stays on kitty's own defaults.
    write_kitty(COLORS_DIR / "kitty.conf", colors)

    apply_live(colors)
    print(json.dumps({"ok": True, "theme": theme, "accent": colors["accent"]}))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(json.dumps({"ok": False, "error": str(e)}), file=sys.stderr)
        sys.exit(1)
