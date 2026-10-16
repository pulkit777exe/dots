local mod = "SUPER"
local step = 20

local moves = {
    left = { -step, 0 },
    right = { step, 0 },
    up = { 0, -step },
    down = { 0, step },
}

for key, xy in pairs(moves) do
    hl.bind(
        mod .. " + CTRL + " .. key,
        hl.dsp.window.resize({
            x = xy[1],
            y = xy[2],
            relative = true,
        }),
        {
            repeating = true,
        }
    )
end
