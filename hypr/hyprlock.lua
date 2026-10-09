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
-- Colours: every colour below is interpolated from the generated palette at
-- ~/.config/colors/current.json (publish-colors.py rewrites it on every
-- palette push), so the lock screen follows the desktop instead of freezing
-- on whatever palette it was authored against. Only alpha levels are
-- literal; if no palette exists the conf is left untouched.
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

-- The palette behind every colour in the conf. Keys used: background,
-- surface (glass pills), text, border (hairlines; its own alpha is
-- stripped and the per-element alphas below re-applied).
local function read_palette()
    local f = io.open(os.getenv("HOME") .. "/.config/colors/current.json", "r")
    if not f then
        return nil
    end

    local contents = f:read("*a")
    f:close()

    local colors = {}
    for key, hex in contents:gmatch('"([%w_]+)"%s*:%s*"#([0-9a-fA-F]+)"') do
        colors[key] = hex
    end

    if not (colors.background and colors.surface and colors.text and colors.border) then
        return nil
    end
    return colors
end

local palette = read_palette()
if not palette then
    io.stderr:write(
        "hyprlock.lua: no palette at ~/.config/colors/current.json; "
            .. "leaving hyprlock.conf untouched\n"
    )
    return
end

local function rgba(hex, alpha)
    return "rgba(" .. hex .. alpha .. ")"
end

-- The border token carries its own alpha; per-element hairline strengths
-- re-apply it below, so keep only its RGB.
local ring = palette.border:gsub("#", "")
if #ring == 8 then
    ring = ring:sub(3)
end

local colours = {
    ["{{bg}}"] = rgba(palette.background, "ff"),     -- lock fallback fill
    ["{{veil}}"] = rgba(palette.background, "61"),   -- 0.38, status pill
    ["{{glass}}"] = rgba(palette.surface, "8c"),     -- 0.55, power pills
    ["{{text92}}"] = rgba(palette.text, "eb"),       -- 0.92, labels
    ["{{text90}}"] = rgba(palette.text, "e6"),       -- 0.90, username/dots
    ["{{text55}}"] = rgba(palette.text, "8c"),       -- 0.55, hint
    ["{{clear}}"] = rgba(palette.background, "00"),  -- alpha 0: invisible
    ["{{hair14}}"] = rgba(ring, "24"),               -- 0.14, status pill
    ["{{hair16}}"] = rgba(ring, "29"),               -- 0.16, power pills
    ["{{ring25}}"] = rgba(ring, "40"),               -- 0.25, avatar ring
}

local config = [[
background {
    monitor =
    path = screenshot
    color = {{bg}}
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
    color = {{veil}}
    rounding = 10
    border_size = 1
    border_color = {{hair14}}
    position = 870, 493
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:10000] ~/.config/hypr/hyprlock/scripts/battery.sh
    color = {{text92}}
    font_size = 15
    font_family = SF Pro Display
    position = 870, 493
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:5000] ~/.config/hypr/hyprlock/scripts/wifi.sh
    color = {{text92}}
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
    color = {{text92}}
    font_size = 26
    font_family = SF Pro Display
    position = 0, 399
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:1000] date '+%I:%M'
    color = {{text92}}
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
    border_color = {{ring25}}
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
    color = {{text90}}
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
    color = {{text55}}
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
    outer_color = {{clear}}
    inner_color = {{clear}}
    font_color = {{text90}}
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
    color = {{glass}}
    rounding = 20
    border_size = 1
    border_color = {{hair16}}
    position = -87, -492
    halign = center
    valign = center
    onclick = systemctl poweroff
}

label {
    monitor =
    text = Shut Down
    color = {{text92}}
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
    color = {{glass}}
    rounding = 20
    border_size = 1
    border_color = {{hair16}}
    position = 87, -492
    halign = center
    valign = center
    onclick = systemctl reboot
}

label {
    monitor =
    text = Restart
    color = {{text92}}
    font_size = 14
    font_family = SF Pro Display
    position = 87, -492
    halign = center
    valign = center
    onclick = systemctl reboot
}
]]

for token, value in pairs(colours) do
    config = config:gsub(token, value)
end

local path = os.getenv("HOME") .. "/.config/hypr/hyprlock.conf"

local file = assert(io.open(path, "w"))
file:write(config)
file:close()
