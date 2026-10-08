-- hyprlock.lua
-- Generates ~/.config/hypr/hyprlock.conf, which is what hyprlock actually
-- reads (v0.9.6 uses the .conf format; QML configs are legacy and go away in
-- 0.10). hyprland.lua requires this file at startup, so every login rebuilds
-- the conf; after editing, run it by hand for an immediate rebuild:
--
--     lua ~/.config/hypr/hyprlock.lua
--
-- Layout, macOS-style: the live desktop blurred behind everything, date and
-- clock in the upper third, battery + wifi top right, avatar / username /
-- password hint in the lower third, and Shut Down / Restart pills along the
-- bottom. Nothing else -- no song strip, no stray prompts.
--
-- Geometry, PROVEN against live runs on the 1920x1080 panel (not derived
-- from theory like the previous revision): `position` is in PIXELS from the
-- widget's alignment anchor, and with valign = center positive y moves UP.
-- So a target screen coordinate (x, y) becomes position (x - 960, 540 - y):
--
--     element       target centre      position
--     date             0, 141            0, 399
--     clock            0, 232.5          0, 307.5
--     battery      1830, 47           870, 493
--     wifi         1884, 47           924, 493
--     avatar           0, 865            0, -325
--     username         0, 926            0, -386
--     hint + field     0, 972            0, -432
--     power pills  y 1032              0, -492   (x 873 -> -87, 1047 -> 87)
--
-- The old revision treated `position` as a percent of the monitor, which
-- was never run: every element piled up in a heap at the centre of the
-- screen instead.
--
-- Background is `screenshot`: hyprlock snapshots the desktop when it starts
-- and blurs it, so the lock always carries what the user was actually
-- looking at (wallpaper, windows, anything) and never depends on a wallpaper
-- path -- the previous hardcoded ~/Downloads path had died and rendered a
-- black screen.
--
-- Shut Down / Restart use hyprlock's `onclick` on both the pill shape and
-- its label, so a click anywhere on the pill lands.

local config = [[
background {
    monitor =
    path = screenshot
    color = rgba(34, 32, 32, 1.0)
    blur_passes = 3
    contrast = 0.8916
    brightness = 0.8172
    vibrancy = 0.1696
    vibrancy_darkness = 0.0
}

general {
    immediate_render = true
}

# ── Status row, top right ─────────────────────────────────────────────────
# hyprlock has no battery or network widget; both are labels polling tiny
# scripts (hypr/hyprlock/scripts/). The pill behind the percent is a shape,
# drawn first so the label sits on top.

shape {
    monitor =
    size = 82, 34
    color = rgba(0, 0, 0, 0.38)
    rounding = 10
    border_size = 1
    border_color = rgba(255, 255, 255, 0.14)
    position = 870, 493
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:10000] ~/.config/hypr/hyprlock/scripts/battery.sh
    color = rgba(238, 240, 235, 0.92)
    font_size = 15
    font_family = SF Pro Display
    position = 870, 493
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:5000] ~/.config/hypr/hyprlock/scripts/wifi.sh
    color = rgba(238, 240, 235, 0.92)
    font_size = 17
    font_family = JetBrainsMonoNL Nerd Font Mono
    position = 924, 493
    halign = center
    valign = center
}

# ── Clock, upper third ────────────────────────────────────────────────────
# Single quotes around the date formats: hyprlock runs the command through a
# shell, and the old backslash-escaped double quotes arrived at date(1) as
# literal quote characters -- "extra operand" every second, date never
# rendered, and the time wore quote marks.

label {
    monitor =
    text = cmd[update:1000] date '+%A, %B %d'
    color = rgba(238, 240, 235, 0.92)
    font_size = 26
    font_family = SF Pro Display
    position = 0, 399
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:1000] date '+%I:%M'
    color = rgba(238, 240, 235, 0.92)
    font_size = 120
    font_family = SF Pro Display
    position = 0, 307.5
    halign = center
    valign = center
}

# ── User block, lower third ───────────────────────────────────────────────

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
    position = 0, -325
    halign = center
    valign = center
}

label {
    monitor =
    text = $USER
    color = rgba(238, 240, 235, 0.90)
    font_size = 15
    font_family = SF Pro Display
    position = 0, -386
    halign = center
    valign = center
}

# The hint sits at the same spot as the field: the field is transparent at
# rest (the hint shows), and typing draws the dots over the hint -- the
# reference's mid-typing state. placeholder_text must be set explicitly
# empty: absent means hyprlock's default "Input Password...", and 0.9.6
# keeps rendering the placeholder while you type instead of clearing it,
# which garbles the dots.

label {
    monitor =
    text = Press any Key to Enter Password
    color = rgba(238, 240, 235, 0.55)
    font_size = 13
    font_family = SF Pro Display
    position = 0, -432
    halign = center
    valign = center
}

input-field {
    monitor =
    size = 260, 34
    outline_thickness = 0
    dots_size = 0.22
    dots_spacing = 0.28
    dots_center = true
    outer_color = rgba(0, 0, 0, 0)
    inner_color = rgba(255, 255, 255, 0)
    font_color = rgba(238, 240, 235, 0.9)
    fade_on_empty = false
    font_family = SF Pro Display
    placeholder_text =
    position = 0, -432
    halign = center
    valign = center
}

# ── Power buttons, bottom ─────────────────────────────────────────────────
# Glass pills like the macOS lock screen. Shape and label both carry onclick
# so the whole pill is a hit target.

shape {
    monitor =
    size = 150, 40
    color = rgba(18, 18, 18, 0.55)
    rounding = 20
    border_size = 1
    border_color = rgba(255, 255, 255, 0.16)
    position = -87, -492
    halign = center
    valign = center
    onclick = systemctl poweroff
}

label {
    monitor =
    text = Shut Down
    color = rgba(238, 240, 235, 0.95)
    font_size = 14
    font_family = SF Pro Display
    position = -87, -492
    halign = center
    valign = center
    onclick = systemctl poweroff
}

shape {
    monitor =
    size = 150, 40
    color = rgba(18, 18, 18, 0.55)
    rounding = 20
    border_size = 1
    border_color = rgba(255, 255, 255, 0.16)
    position = 87, -492
    halign = center
    valign = center
    onclick = systemctl reboot
}

label {
    monitor =
    text = Restart
    color = rgba(238, 240, 235, 0.95)
    font_size = 14
    font_family = SF Pro Display
    position = 87, -492
    halign = center
    valign = center
    onclick = systemctl reboot
}
]]

local path = os.getenv("HOME") .. "/.config/hypr/hyprlock.conf"

local file = assert(io.open(path, "w"))
file:write(config)
file:close()
