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

local ring = palette.border:gsub("#", "")
if #ring == 8 then
    ring = ring:sub(3)
end

local colours = {
    ["{{bg}}"] = rgba(palette.background, "ff"),
    ["{{veil}}"] = rgba(palette.background, "61"),
    ["{{glass}}"] = rgba(palette.surface, "8c"),
    ["{{text92}}"] = rgba(palette.text, "eb"),
    ["{{text90}}"] = rgba(palette.text, "e6"),
    ["{{text55}}"] = rgba(palette.text, "8c"),
    ["{{clear}}"] = rgba(palette.background, "00"),
    ["{{hair14}}"] = rgba(ring, "24"),
    ["{{hair16}}"] = rgba(ring, "29"),
    ["{{ring25}}"] = rgba(ring, "40"),
}

local config = [[
# Wallpaper is shared with the SDDM login theme (sddm/sequoia/wallpaper.jpg,
# linked at ~/.config/sddm/...). Kept blurred like the old screenshot
# background; refresh it with scripts/sync-login-wallpaper.sh after
# changing the desktop wallpaper.
background {
    monitor =
    path = ~/.config/sddm/sequoia/wallpaper.jpg
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

# The pill behind the dots is white-tinted like the SDDM login, so the
# dots are dark ink (a literal, not a palette token: the pill is always
# light, so the dots must always be dark regardless of palette). The
# hint moved below the pill, mirroring SDDM's msgLine, so typing never
# draws dots over it.

shape {
    monitor =
    size = 220, 38
    color = rgba(ffffff40)
    rounding = 19
    border_size = 1
    border_color = rgba(ffffff8c)
    position = 0, -432
    halign = center
    valign = center
}

input-field {
    monitor =
    size = 200, 32
    outline_thickness = 0
    dots_size = 0.22
    dots_spacing = 0.28
    dots_center = true
    outer_color = {{clear}}
    inner_color = {{clear}}
    font_color = rgba(26292fff)
    fade_on_empty = false
    font_family = SF Pro Display
    placeholder_text =
    position = 0, -432
    halign = center
    valign = center
}

label {
    monitor =
    text = Press any Key to Enter Password
    color = {{text55}}
    font_size = 13
    font_family = SF Pro Display
    position = 0, -472
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
