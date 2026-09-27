-- modules/animations.lua
--
-- Hyprland compositor animations.

local bezier = "default"
local speed = 1.0

hl.animation({
    leaf = "windows",
    enabled = true,
    bezier = bezier,
    speed = speed,
})

hl.animation({
    leaf = "fade",
    enabled = true,
    bezier = bezier,
    speed = speed,
})

hl.animation({
    leaf = "workspaces",
    enabled = true,
    bezier = bezier,
    speed = speed,
})

hl.animation({
    leaf = "border",
    enabled = true,
    bezier = bezier,
    speed = speed,
})

hl.animation({
    leaf = "borderangle",
    enabled = true,
    bezier = bezier,
    speed = speed,
})