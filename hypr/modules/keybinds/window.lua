-- modules/keybinds/window.lua
--
-- Window state controls.

local mod = "SUPER"

-- Toggle floating
hl.bind(
    mod .. " + V",
    hl.dsp.window.float({
        action = "toggle",
    })
)

-- Toggle fullscreen
hl.bind(
    mod .. " + F",
    hl.dsp.window.fullscreen({
        state = "toggle",
    })
)

-- Toggle pseudo-tile
hl.bind(
    mod .. " + SHIFT + V",
    hl.dsp.window.pseudo({
        state = "toggle",
    })
)