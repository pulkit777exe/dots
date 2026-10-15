#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
COLORS_DIR = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "colors"
ICONS_DIR = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local" / "share")) / "icons" / "dots"

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

def shade(value: str, factor: float) -> str:
    r, g, b = hex_to_rgb(value)
    r, g, b = (max(0, min(255, round(v * factor))) for v in (r, g, b))
    return f"#{r:02x}{g:02x}{b:02x}"

def folder_svg(body: str, dark: str) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <rect x="4" y="6" width="18" height="9" rx="2.5" fill="{dark}"/>
  <rect x="4" y="11" width="40" height="29" rx="4" fill="{body}"/>
  <path d="M8 11h32a4 4 0 0 1 4 4v3H4v-3a4 4 0 0 1 4-4z" fill="#ffffff" opacity="0.07"/>
</svg>
"""

def folder_open_svg(body: str, dark: str, paper: str) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <rect x="4" y="8" width="40" height="28" rx="4" fill="{dark}"/>
  <rect x="10" y="12" width="28" height="12" rx="1.5" fill="{paper}"/>
  <path d="M4 22a4 4 0 0 1 4-4h32a4 4 0 0 1 4 4v14a4 4 0 0 1-4 4H8a4 4 0 0 1-4-4z" fill="{body}"/>
  <path d="M8 18h32a4 4 0 0 1 4 4v2H4v-2a4 4 0 0 1 4-4z" fill="#ffffff" opacity="0.07"/>
</svg>
"""

INDEX_THEME = """[Icon Theme]
Name=dots
Comment=Palette-matched folders, everything else from Adwaita
Inherits=Adwaita
Directories=places/scalable

[places/scalable]
Size=48
Context=Places
Type=Scalable
MinSize=8
MaxSize=512
"""

def write_icons(colors: dict) -> None:
    body = colors["muted"]
    dark = shade(body, 0.6)
    paper = shade(colors["foreground"], 0.85)
    places = ICONS_DIR / "places" / "scalable"
    places.mkdir(parents=True, exist_ok=True)
    (ICONS_DIR / "index.theme").write_text(INDEX_THEME)
    (places / "folder.svg").write_text(folder_svg(body, dark))
    (places / "folder-open.svg").write_text(folder_open_svg(body, dark, paper))

def gtk_color(value: str) -> str:
    """Palette hex -> GTK3/4-safe CSS. GTK rejects 8-digit #aarrggbb hex,
    so translucent slots become rgba(). Opaque #rgb/#rrggbb pass through."""
    h = value.lstrip("#")
    if len(h) == 8:
        a = int(h[0:2], 16) / 255
        r, g, b = int(h[2:4], 16), int(h[4:6], 16), int(h[6:8], 16)
        return f"rgba({r},{g},{b},{a:.3f})"
    if len(h) == 4:
        a = int(h[0] * 2, 16) / 255
        r, g, b = int(h[1] * 2, 16), int(h[2] * 2, 16), int(h[3] * 2, 16)
        return f"rgba({r},{g},{b},{a:.3f})"
    return value

def hypr_hex(value: str) -> str:
    """Strip a leading alpha byte so Hyprland always gets rrggbb."""
    h = value.lstrip("#")
    if len(h) == 8:
        h = h[2:]
    return h

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
    acc = hypr_hex(colors["accent"])
    surf = hypr_hex(colors["surface"])
    path.write_text(
        f"$bg = rgb({hypr_hex(colors['background'])})\n"
        f"$fg = rgb({hypr_hex(colors['foreground'])})\n"
        f"$accent = rgb({acc})\n"
        f"$surface = rgb({surf})\n"
        f"$red = rgb({hypr_hex(colors['error'])})\n"
        f"$green = rgb({hypr_hex(colors['success'])})\n"
        f"$yellow = rgb({hypr_hex(colors['warning'])})\n"
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

GTK_MARKER = "generated by publish-colors.py"

def gtk_defs(colors: dict) -> str:
    c = {k: (gtk_color(v) if isinstance(v, str) and v.startswith("#") else v)
         for k, v in colors.items()}
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
    return "".join(f"@define-color {name} {value};\n" for name, value in defs)

def write_gtk(path: Path, colors: dict) -> None:
    path.write_text(gtk_defs(colors))

def gtk3_rules(colors: dict) -> str:
    """Explicit GTK3 widget rules with literal colors.

    A user-stylesheet `@define-color` does not override the theme's own
    definitions on this stack (verified: redefined theme_selected_bg_color
    still renders Adwaita blue, while a direct rule in the same file
    applies). So state the rules outright instead of relying on names.
    """
    c = {k: (gtk_color(v) if isinstance(v, str) and v.startswith("#") else v)
         for k, v in colors.items()}
    bg, fg = c["background"], c["foreground"]
    surf, surf_elev = c["surface"], c["surfaceElevated"]
    acc, acc_fg = c["accent"], c["accentText"]
    muted, divider = c["muted"], c["divider"]
    return f"""\
window, window.background, .background {{
  background: {bg};
  color: {fg};
}}
view, treeview.view, iconview.view, list, list row,
textview text, entry {{
  background: {surf};
  color: {fg};
}}
notebook stack {{
  background: {bg};
}}
row:selected, treeview:selected, iconview:selected,
list row:selected, *:selected, selection,
entry selection, textview selection {{
  background: {acc};
  color: {acc_fg};
}}
headerbar, .titlebar, toolbar, menubar {{
  background: {surf};
  color: {fg};
  border-color: {divider};
}}
placessidebar.sidebar, .sidebar {{
  background: {surf};
  color: {fg};
}}
placessidebar.sidebar row:selected, .sidebar row:selected {{
  background: {acc};
  color: {acc_fg};
}}
popover, menu, menu menuitem {{
  background: {surf_elev};
  color: {fg};
}}
menuitem:hover, menu menuitem:hover {{
  background: {acc};
  color: {acc_fg};
}}
button.suggested-action {{
  background: {acc};
  color: {acc_fg};
  border-color: transparent;
}}
switch:checked {{
  background: {acc};
}}
check:checked, radio:checked {{
  color: {acc};
}}
scrollbar slider {{
  background: {muted};
  border-color: transparent;
}}
separator {{
  color: {divider};
  background: {divider};
}}
"""

def gtk4_rules(colors: dict) -> str:
    """Explicit GTK4 rules with literal colors.

    Same finding as GTK3 (see gtk3_rules): `@define-color` redefinition in
    the user stylesheet does not move plain GTK4 widgets either — a
    .suggested-action button stays Adwaita blue with accent_bg_color
    redefined. State the accent rules outright.
    """
    c = {k: (gtk_color(v) if isinstance(v, str) and v.startswith("#") else v)
         for k, v in colors.items()}
    acc, acc_fg = c["accent"], c["accentText"]
    # `background:` (shorthand), not `background-color`: the theme paints
    # accent widgets with background-image: image(@accent_bg_color), which
    # sits over any background-color. The shorthand resets the image.
    return f"""\
*:selected, selection {{
  background: {acc};
  color: {acc_fg};
}}
button.suggested-action {{
  background: {acc};
  color: {acc_fg};
}}
check:checked, radio:checked {{
  color: {acc};
  -gtk-icon-filter: none;
}}
switch:checked {{
  background: {acc};
}}
"""

def run(cmd: list[str]) -> None:
    try:
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4)
    except Exception as e:
        print(f"publish-colors: {' '.join(cmd)} failed: {e}", file=sys.stderr)

def apply_live(colors: dict) -> None:
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
    live = COLORS_DIR == config_home / "colors"

    if live:
        run(["hyprctl", "reload"])

    is_dark = hex_lightness(colors["background"]) < 0.5
    stale_marker = "generated by apply-theme-colors.sh"
    import_line = '@import url("colors.css");\n'
    gtk3_css = f"/* {GTK_MARKER} - do not hand-edit */\n" + gtk_defs(colors) + gtk3_rules(colors)
    gtk4_css = f"/* {GTK_MARKER} - do not hand-edit */\n" + gtk_defs(colors) + gtk4_rules(colors)
    for d, content in ((config_home / "gtk-3.0", gtk3_css),
                       (config_home / "gtk-4.0", gtk4_css)):
        d.mkdir(parents=True, exist_ok=True)
        write_gtk(d / "colors.css", colors)
        css = d / "gtk.css"
        existing = css.read_text() if css.is_file() else ""
        if (not existing.strip() or GTK_MARKER in existing
                or stale_marker in existing
                or existing.strip() == import_line.strip()):
            css.write_text(content)
        elif content.split("\n", 1)[0] not in existing:
            css.write_text(content + existing)
        (d / "settings.ini").write_text(
            "[Settings]\n"
            "gtk-theme-name=Adwaita\n"
            "gtk-icon-theme-name=dots\n"
            "gtk-application-prefer-dark-theme="
            + ("1" if is_dark else "0")
            + "\n"
        )

    if not live:
        return
    write_icons(colors)
    run([
        "gsettings", "set", "org.gnome.desktop.interface",
        "icon-theme", "dots",
    ])
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
