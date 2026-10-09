#!/usr/bin/env python3
"""Publish a theme's static palette into ~/.config/colors for the whole desktop.

The palette is hand-authored and lives at
~/.config/colors/themes/<name>/colors.json — there is no generator and no
sampling. This script is the shared desktop layer: it copies that palette
out to the files Hyprland/GTK/CSS/kitty consumers read and pushes it to
whatever is already running.

Active palette resolution, highest priority first:
  1. CLI argument:      publish-colors.py <name>
  2. $QUICKSHELL_THEME
  3. `current` in ~/.config/colors/index.json (falls back to `default`)
  4. "ariadne"
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
COLORS_DIR = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "colors"

# Cached result of hyprland_uses_new_parsers(); None until first checked.
_NEW_PARSERS: bool | None = None
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
    """The palette GTK reads: the classic GTK3 names plus the full set of
    named colours current libadwaita/GTK4 apps resolve, so both
    generations of GTK apps follow the palette."""
    c = colors
    defs = [
        # GTK3 classics
        ("theme_bg_color", c["background"]),
        ("theme_fg_color", c["foreground"]),
        ("theme_selected_bg_color", c["accent"]),
        ("theme_selected_fg_color", c["accentText"]),
        ("theme_base_color", c["surface"]),
        ("theme_text_color", c["foreground"]),
        ("borders", c["surfaceAlt"]),
        # libadwaita / current GTK4
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


def hyprland_uses_new_parsers() -> bool:
    """True on Hyprland 0.56+, which refuses `hyprctl keyword`.

    `hyprctl keyword` answers "keyword can't work with non-legacy parsers.
    Use eval." and changes nothing. The suggested eval route is a dead end
    too: on 0.56 eval takes Lua, exposes no keyword helper, and returns a
    bare "ok" for everything, so it cannot be driven or verified. The path
    that does work is to reload, because write_hypr has already written
    colors/hyprland.conf and hypr/modules/general.lua re-reads it on load.

    Cached: this runs on every theme switch.
    """
    global _NEW_PARSERS
    if _NEW_PARSERS is not None:
        return _NEW_PARSERS

    version = ""
    try:
        proc = subprocess.run(["hyprctl", "version"], capture_output=True, text=True, timeout=3)
        version = proc.stdout or ""
    except Exception:
        version = ""

    parts: list[str] = []
    for token in version.replace(",", " ").split():
        if token[:1].isdigit() and "." in token:
            parts = token.split(".")
            break
    try:
        major = int(parts[0]) if parts else 0
        minor = int(parts[1]) if len(parts) > 1 else 0
    except ValueError:
        major, minor = 0, 0

    # 0.56 is the Lua-config/new-parser rewrite. Older Hyprland still takes
    # `hyprctl keyword`. An unreadable version stays on the old path so we
    # never reload Hyprland speculatively.
    _NEW_PARSERS = (major, minor) >= (0, 56) if (major or minor) else False
    return _NEW_PARSERS


def apply_live(colors: dict) -> None:
    """Push the palette to things already running.

    GTK files land under the same XDG root the palette resolved from, so
    scratch publishes (the tests run it per palette) stay in their
    sandbox; borders, gsettings and the kitty sockets are only touched
    when publishing to the real ~/.config/colors.
    """
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
    live = COLORS_DIR == HOME / ".config" / "colors"

    acc = colors["accent"].lstrip("#")
    surf = colors["surface"].lstrip("#")
    if len(acc) == 8:
        acc = acc[2:]
    if len(surf) == 8:
        surf = surf[2:]

    if live and hyprland_uses_new_parsers():
        # general.lua re-reads colors/hyprland.conf on load, so reloading is
        # what actually applies the new border colours on 0.56+.
        run(["hyprctl", "reload"])
    elif live:
        run(["hyprctl", "keyword", "general:col.active_border", f"rgba({acc}ff)"])
        run(["hyprctl", "keyword", "general:col.inactive_border", f"rgba({surf}aa)"])

    gtk3_dir = config_home / "gtk-3.0"
    gtk4_dir = config_home / "gtk-4.0"
    for gtk_dir in (gtk3_dir, gtk4_dir):
        gtk_dir.mkdir(parents=True, exist_ok=True)
    write_gtk(gtk3_dir / "colors.css", colors)
    write_gtk(gtk4_dir / "colors.css", colors)
    # gtk.css must stay a pure @import: an earlier generator wrote its
    # palette inline there, and GTK keeps the *last* definition of a
    # name, so those stale inline defines outvoted the fresh colors.css
    # and apps sat on the old theme. Rewrite when the file is still that
    # generator's residue; otherwise only guarantee the import so any of
    # the user's own gtk.css customizations survive.
    stale_marker = "generated by apply-theme-colors.sh"
    for gtk_dir in (gtk3_dir, gtk4_dir):
        gtk_css = gtk_dir / "gtk.css"
        if gtk_css.is_file() and stale_marker in gtk_css.read_text():
            gtk_css.write_text('@import url("colors.css");\n')
        else:
            ensure_gtk_import(gtk_css)

    # The color-scheme signal is what actually matters for most GTK3/
    # GTK4/libadwaita apps in practice — the @define-color overrides
    # above only take effect on apps using an older, non-libadwaita
    # GTK3 theme that references theme_bg_color/theme_selected_bg_color
    # by name. A libadwaita app picks its own dark/light palette from
    # this setting and largely ignores arbitrary accent hex values
    # (GNOME's own accent-color setting is a fixed named palette, not
    # arbitrary hex, so we don't attempt to force it here).
    is_dark = hex_lightness(colors["background"]) < 0.5
    for gtk_dir in (gtk3_dir, gtk4_dir):
        (gtk_dir / "settings.ini").write_text(
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

    # kitty follows live too: kitty.conf includes the generated palette
    # for future launches, and this repaints the instances already open.
    kitty_conf = COLORS_DIR / "kitty.conf"
    for sock in sorted(Path("/tmp").glob("kitty-*")):
        run(["kitty", "@", "--to", f"unix:{sock}", "set-colors", "-a", str(kitty_conf)])


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
    """Read a palette's own hand-authored colors.json.

    There is no fallback fill: the tests enforce that every palette
    carries the same complete key set, so a missing key here means the
    file was hand-broken and publishing must fail loudly rather than
    quietly render parts of the desktop with invented colours.
    """
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

    # Record what was actually published: index.json's `current` had gone
    # stale (nothing wrote it), so a bare publish resolved to the default
    # and repainted a live desktop in another theme's colours.
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
    # kitty.conf includes this file, and apply_live() pushes it to open
    # terminals — the terminal is part of the themed desktop.
    write_kitty(COLORS_DIR / "kitty.conf", colors)

    apply_live(colors)
    print(json.dumps({"ok": True, "theme": theme, "accent": colors["accent"]}))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(json.dumps({"ok": False, "error": str(e)}), file=sys.stderr)
        sys.exit(1)
