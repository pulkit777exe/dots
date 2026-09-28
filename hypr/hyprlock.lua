-- hyprlock.lua
-- Generates ~/.config/hypr/hyprlock.conf, which is what hyprlock actually
-- reads (v0.9.6 uses the .conf format; QML configs are legacy and go away in
-- 0.10). Run from hyprland.lua's startup.
--
-- Geometry is matched to the reference capture 2026-09-20_22-27-37, a 1:1
-- 1920x1080 frame. hyprlock's `position` is a *percentage of the monitor*
-- applied from the alignment anchor, so for a 1080px screen and valign=center
-- an offset of P percent lands the element's centre at 540 + P*10.8 px.
--
-- The previous values here were `0, 350` for the date and `0, 40` for the
-- avatar, which put the date three and a half screens below the centre and
-- the avatar ~972px down -- nothing like the reference, and on a 1080 screen
-- the date would have been off-screen entirely.
--
-- NOT VERIFIED BY RUNNING. hyprlock has no --verify or dry-run (only --help,
-- --version, --verbose, --quiet, --config, --grace, --immediate-render,
-- --no-fade-in, --display), and launching it would lock the session with no
-- way to unlock it from here. This is written against the 0.9.6 config
-- reference and checked by reading, not by execution.
local config = [[
# BACKGROUND
# The reference is a heavily blurred, high-contrast wash of the wallpaper --
# the scene is unrecognisable, only its colour and light direction survive.
# blur_passes 3 plus a contrast/brightness push is what gets there; a plain
# blur reads as "blurred wallpaper" rather than "this".
background {
    monitor =
    path = ~/Downloads/everforest/wallhaven-9o8k9w_1920x1080.png
    blur_passes = 3
    contrast = 0.8916
    brightness = 0.8172
    vibrancy = 0.1696
    vibrancy_darkness = 0.0
}

general {
    no_fade_in = false
    grace = 0
    disable_loading_bar = false
}

# ── Clock ────────────────────────────────────────────────────────────────
# Date above, time below it, both centred, sitting in the upper third.

# Day-Month-Date  --  centre at y ~140, i.e. 400px above centre = -37%
label {
    monitor =
    text = cmd[update:1000] echo -e "$(date +\"%A, %B %d\")"
    color = rgba(238, 240, 235, 0.92)
    font_size = 26
    font_family = SF Pro Display
    position = 0, -37
    halign = center
    valign = center
}

# Time  --  centre at y ~235, i.e. -28%
# %I is the reference's own format: it renders 0:47, not 00:47.
label {
    monitor =
    text = cmd[update:1000] echo "<span>$(date +\"%I:%M\")</span>"
    color = rgba(238, 240, 235, 0.92)
    font_size = 120
    font_family = SF Pro Display
    position = 0, -28
    halign = center
    valign = center
}

# ── User block, lower third ──────────────────────────────────────────────

# Avatar  --  centre at y ~863, i.e. +30%. 52px in the reference, a
# circle, with a hairline ring.
image {
    monitor =
    path = ~/.config/hypr/hyprlock/assets/avatar.jpeg
    border_size = 2
    border_color = rgba(255, 255, 255, 0.25)
    size = 52
    rounding = -1
    rotate = 0
    reload_time = -1
    reload_cmd =
    position = 0, 30
    halign = center
    valign = center
}

# Username  --  y ~925, i.e. +35.6%
label {
    monitor =
    text = $USER
    color = rgba(238, 240, 235, 0.90)
    font_size = 15
    font_family = SF Pro Display
    position = 0, 35.6
    halign = center
    valign = center
}

# ── Prompt ───────────────────────────────────────────────────────────────
# The reference shows "Press any Key to Enter Password" and no visible input.
# hyprlock has no "press any key" widget, so the field is always present but
# its *dots* are suppressed (hide_input = true): the field is invisible and
# unfocusable-looking at rest, and the moment a key is pressed the dots appear
# in its place. The label sits behind the field, so it is covered exactly when
# the dots show.

label {
    monitor =
    text = Press any Key to Enter Password
    color = rgba(238, 240, 235, 0.55)
    font_size = 13
    font_family = SF Pro Display
    position = 0, 39.8
    halign = center
    valign = center
}

input-field {
    monitor =
    size = 260, 34
    center_color = rgba(238, 240, 235, 0.9)
    outline_thickness = 0
    dots_size = 0.22
    dots_spacing = 0.28
    dots_center = true
    outer_color = rgba(0, 0, 0, 0)
    inner_color = rgba(255, 255, 255, 0)
    font_color = rgba(238, 240, 235, 0.9)
    fade_on_empty = false
    hide_input = true
    font_family = SF Pro Display
    placeholder_text = <i><span foreground="##ffffff99">Password</span></i>
    position = 0, 39.8
    halign = center
    valign = center
}

# ── Not in the reference, kept for the music case ────────────────────────
# Left at the very bottom edge so it cannot collide with the user block.
label {
    monitor =
    text = cmd[update:2000] echo "$(~/.config/hypr/hyprlock/scripts/songdetail.sh)"
    color = rgba(255, 255, 255, 0.45)
    font_size = 14
    font_family = JetBrains Mono Nerd, SF Pro Display
    position = 0, 46
    halign = center
    valign = center
}

# NOTE: the reference also shows a battery pill and a wifi glyph in the top
# right corner. hyprlock 0.9.6 has no battery or network widget -- the only
# widgets are shape, image, label, input-field, textarea, color and
# background -- so those cannot be reproduced here. They would need either a
# newer hyprlock or a label polling a script like songdetail.sh does.
]]

local path = os.getenv("HOME") .. "/.config/hypr/hyprlock.conf"

local file = assert(io.open(path, "w"))
file:write(config)
file:close()
