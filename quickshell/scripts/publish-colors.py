#!/usr/bin/env python3

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
DEFAULT_THEME = "ariadne"

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

def write_gtk(path: Path, colors: dict) -> None:
    c = colors
    defs = [
        ("theme_bg_color", c["background"]),
        ("theme_fg_color", c["foreground"]),
        ("theme_selected_bg_color", c["accent"]),
        ("theme_selected_fg_color", c["accentText"]),
        ("theme_base_color", c["surface"]),
        ("theme_text_color", c["foreground"]),
        ("borders", c["surfaceAlt"]),
        ("window_bg_color", c["background"]),
        ("window_fg_color", c["foreground"]),
        ("window_backdrop_fg_color", c["muted"]),
        ("view_bg_color", c["surface"]),
        ("view_fg_color", c["foreground"]),
        ("view_backdrop_fg_color", c["muted"]),
        ("headerbar_bg_color", c["surface"]),
        ("headerbar_fg_color", c["foreground"]),
        ("headerbar_backdrop_fg_color", c["muted"]),
        ("headerbar_border_color", c["divider"]),
        ("headerbar_shade_color", c["surfaceMuted"]),
        ("sidebar_bg_color", c["surface"]),
        ("sidebar_fg_color", c["foreground"]),
        ("sidebar_backdrop_fg_color", c["muted"]),
        ("sidebar_border_color", c["divider"]),
        ("sidebar_shade_color", c["surfaceMuted"]),
        ("popover_bg_color", c["surfaceElevated"]),
        ("popover_fg_color", c["foreground"]),
        ("dialog_bg_color", c["surfaceElevated"]),
        ("dialog_fg_color", c["foreground"]),
        ("card_bg_color", c["surfaceElevated"]),
        ("card_fg_color", c["foreground"]),
        ("thumbnail_bg_color", c["surfaceAlt"]),
        ("thumbnail_fg_color", c["foreground"]),
        ("accent_color", c["accent"]),
        ("accent_bg_color", c["accent"]),
        ("accent_fg_color", c["accentText"]),
        ("destructive_color", c["error"]),
        ("destructive_bg_color", c["error"]),
        ("destructive_fg_color", c["accentText"]),
        ("error_color", c["error"]),
        ("error_bg_color", c["error"]),
        ("error_fg_color", c["accentText"]),
        ("success_color", c["success"]),
        ("success_bg_color", c["success"]),
        ("success_fg_color", c["accentText"]),
        ("warning_color", c["warning"]),
        ("warning_bg_color", c["warning"]),
        ("warning_fg_color", c["accentText"]),
        ("shade_color", c["surfaceMuted"]),
        ("scrollbar_outline_color", c["muted"]),
    ]
    path.write_text("".join(f"@define-color {name} {value};\n" for name, value in defs))

def run(cmd: list[str]) -> None:
    try:
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4)
    except Exception:
        pass

def apply_live(colors: dict) -> None:
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
    live = COLORS_DIR == HOME / ".config" / "colors"

    if live:
        run(["hyprctl", "reload"])

    is_dark = hex_lightness(colors["background"]) < 0.5
    stale_marker = "generated by apply-theme-colors.sh"
    import_line = '@import url("colors.css");\n'
    for d in (config_home / "gtk-3.0", config_home / "gtk-4.0"):
        d.mkdir(parents=True, exist_ok=True)
        write_gtk(d / "colors.css", colors)
        css = d / "gtk.css"
        existing = css.read_text() if css.is_file() else ""
        if stale_marker in existing:
            css.write_text(import_line)
        elif import_line not in existing:
            css.write_text(import_line + existing)
        (d / "settings.ini").write_text(
            "[Settings]\ngtk-application-prefer-dark-theme="
            + ("1" if is_dark else "0")
            + "\n"
        )

    if not live:
        return
    run([
        "gsettings", "set", "org.gnome.desktop.interface",
        "color-scheme", "prefer-dark" if is_dark else "default",
    ])
    kitty_conf = COLORS_DIR / "kitty.conf"
    for sock in sorted(Path("/tmp").glob("kitty-*")):
        run(["kitty", "@", "--to", f"unix:{sock}", "set-colors", "-a", str(kitty_conf)])

def resolve_theme(cli_theme: str | None) -> str:
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

    path = COLORS_DIR / "themes" / theme / "colors.json"
    if not path.is_file():
        raise FileNotFoundError(f"no colors.json for palette {theme!r} ({path})")
    palette = json.loads(path.read_text())
    if not isinstance(palette, dict):
        raise ValueError(f"{path} is not a colour palette object")
    return {k: v for k, v in palette.items() if isinstance(v, str)}

def main():
    theme = resolve_theme(sys.argv[1] if len(sys.argv) > 1 else None)
    colors = load_theme_palette(theme)
    COLORS_DIR.mkdir(parents=True, exist_ok=True)

    if INDEX_JSON.is_file():
        try:
            index = json.loads(INDEX_JSON.read_text())
            index["current"] = theme
            INDEX_JSON.write_text(json.dumps(index, indent=2) + "\n")
        except Exception:
            pass

    (COLORS_DIR / "current.json").write_text(json.dumps(colors, indent=2))
    write_css(COLORS_DIR / "colors.css", colors)
    write_sh(COLORS_DIR / "colors.sh", colors)
    write_hypr(COLORS_DIR / "hyprland.conf", colors)
    write_gtk(COLORS_DIR / "gtk.css", colors)
    write_kitty(COLORS_DIR / "kitty.conf", colors)

    apply_live(colors)
    print(json.dumps({"ok": True, "theme": theme, "accent": colors["accent"]}))

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(json.dumps({"ok": False, "error": str(e)}), file=sys.stderr)
        sys.exit(1)
