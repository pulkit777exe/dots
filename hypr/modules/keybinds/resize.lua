-- modules/keybinds/resize.lua
--
-- Keyboard-driven window resizing.

local mod = "SUPER"
local step = 20

hl.bind(
    mod .. " + CTRL + left",
    hl.dsp.window.resize({
        x = -step,
        y = 0,
        relative = true,
    }),
    {
        repeating = true,
    }
)

hl.bind(
    mod .. " + CTRL + right",
    hl.dsp.window.resize({
        x = step,
        y = 0,
        relative = true,
    }),
    {
        repeating = true,
    }
)

hl.bind(
    mod .. " + CTRL + up",
    hl.dsp.window.resize({
        x = 0,
        y = -step,
        relative = true,
    }),
    {
        repeating = true,
    }
)

hl.bind(
    mod .. " + CTRL + down",
    hl.dsp.window.resize({
        x = 0,
        y = step,
        relative = true,
    }),
    {
        repeating = true,
    }
)