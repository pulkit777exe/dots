-- modules/keybinds/mouse.lua
--
-- Mouse-based window management.

local mod = "SUPER"

-- Move
hl.bind(
    mod .. " + mouse:272",
    hl.dsp.window.drag(),
    {
        mouse = true,
    }
)

-- Resize
hl.bind(
    mod .. " + mouse:273",
    hl.dsp.window.resize(),
    {
        mouse = true,
    }
)